ruleset gossip_protocol {
  meta {
    shares __testing, createMessages, highestSequence, createSeen, getNotSeen, dummy, getPeer, prepareMessage
    use module io.picolabs.subscription alias subscription
    use module temperature_store alias store
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" }
      , { "name": "dummy" }
      , { "name": "createMessages", "args": ["temps"] }
      , { "name": "createSeen", "args": ["messages"]   }
      , { "name": "getNotSeen" }
      , { "name": "highestSequence", "args": ["MsgID"] }
      , { "name": "getPeer", "args": ["state"]}
      , { "name": "prepareMessage", "args": ["type", "state", "subscriber"]}
      //, { "name": "entry", "args": [ "key" ] }
      ] , "events":
      [ { "domain": "gossip", "type": "startup", "attrs":[ "n" ] }
      , { "domain": "gossip", "type": "restart" }
      , { "domain": "gossip", "type": "heartbeat" }
      , { "domain": "gossip", "type": "status", "attrs":["status"] }
      //,{ "domain": "gossip", "type:" "startup", "attrs":[ "n" ] }
      ]
    }
    
    dummy = function() {
      ["blah", "blah2", "blah3"].difference(["blah", "blah2"])
    }
    
    createMessages = function(temps) {
      numTemperatures = ent:temperatures.length()
      map = temps.map(function(x, c){
        {
          "MessageID": meta:picoId +":"+ (numTemperatures + c),
          "SensorID": meta:picoId,
          "temperature": x{"temperature"},
          "timestamp": x{"timestamp"}
          
        }
      })
      map
    }
    
    createSeen = function(messages) {
      allMessageIds = messages.map(function(x){
        x{"MessageID"}
      })
      
      idsWithNoSequence = allMessageIds.map(function(x) {
        x.split(":")[0] 
      })
      
      noDups = idsWithNoSequence.reduce(function(a, b){
        (a><b) => a | a.append(b)
      }, [])
      
      seen = noDups.map(function(x){
        x + ":" + highestSequence(x, messages)
      })
      
      seen
    }
    
    ext = function(MsgID) {
      Id = MsgID.extract(re#^(.*):[0-9][0-9]*$#);
      Id
    }
    
    highestSequence = function(MsgID, messages) {
      found = messages.filter(function(x){
        arr = ext(x{"MessageID"})
        MsgID == arr[0];  
      }).map(function(x){x{"MessageID"}})
      sortedFound = found.sort()
      arrayNum = sortedFound.map(function(x){
        val = x.substr(MsgID.length()+1).decode();
        val;
      })
      //arrayNum.klog("arrayNum");
      //arrayNum = arrayNum.append(8);
      sorted = arrayNum.sort()
      num = sorted.reduce(function(a,x){(x.klog("x") == (a+1).klog("a+1")).klog("result") => x | a},0);
      //arrayNum[arrayNum.length()-1];
      num
    }
    
    getNotSeen = function(seen, otherSeen) {
      //seen = ["ck86lhuxl000yh6zf2kkt74j8:0"]
      
      otherSeenInfo = otherSeen.reduce(function(a, b) {
        a.put(ext(b)[0], { "snum": b.split(":")[1] })
      }, {}).klog("otherSeenInfo")
      

      idsWithNoSequence = otherSeen.map(function(x) {
        x.split(":")[0] 
      })
      
      noDups = idsWithNoSequence.reduce(function(a, b){
        (a><b) => a | a.append(b)
      }, [])
      
      notSeen = seen.map(function(x){
        noDups >< ext(x)[0]  => ent:messages.filter(function(y){ ext(x)[0] == ext(y{"MessageID"})[0] && otherSeenInfo{ext(x)[0]}{"snum"} < y{"MessageID"}.split(":")[1].as("Number") }) 
                              | ent:messages.filter(function(z){ ext(z{"MessageID"})[0] == ext(x)[0] })
      })
      
      notSeen.reduce(function(a, b){
        a.append(b)
      },[])
    }
    
    checkDup = function(rumor) {
      ent:messages >< rumor
    }
    
    getNewTemperatures = function(temps) {
      temps.difference(ent:temperatures)
    }
    
    getPeer = function (state) {
      gossipers = subscription:established("Tx_role", "node")
      gossiper = gossipers.head()
        
      peer = gossipers.reduce(function(a, b) {
        ( not ent:othersSeen{b{"Tx"}}.isnull() && ent:othersSeen{b{"Tx"}}.difference(state).length() < ent:othersSeen{a{"Tx"}}.difference(state).length() ) => a | b
      }, gossiper)
      
      peer.head()
    }
    
    prepareMessage = function(type, state, otherSeen) {
      (type == 1) => state | rumorMessage(state, otherSeen)
    }
    
    rumorMessage = function(state, otherSeen) {
      getNotSeen(state, otherSeen)[0]
    }
    
  }
  
  rule gossip_heartbeat {
    select when gossip heartbeat where ent:status == "on"
    pre {
      type = (not ent:messages.isnull() || ent:messages.length() == 0).klog("result") => random:integer(1) | 1
      temps = getNewTemperatures(store:temperatures()).klog("temps")
      newMessages = createMessages(temps).klog("newMessages")
      allMessages = ent:messages.append(newMessages).klog("allMessages")
      currentSeen = createSeen(allMessages).klog("currentSeen")
      subscriber = getPeer(currentSeen).klog("subscriber")                    
      m = prepareMessage(type.klog("type"), currentSeen, ent:othersSeen.klog("b before"){subscriber{"Tx"}}.klog("before").defaultsTo([]).klog("after")).klog("m")
      event = (type == 1) => {"eci": subscriber{"Tx"}, "domain": "gossip", "type": "seen", "attrs": { "theirRx": subscriber{"Rx"}, "seen": m }} | {"eci": subscriber{"Tx"}, "domain": "gossip", "type": "rumor", "attrs": { "rumor": m }}
    }
    //send (subscriber, m)
      if not (type == 0 && m.isnull()) then
        event:send(event)
    always {
      //update(state)
      ent:temperatures := (temps.length() == 0) => ent:temperatures | ent:temperatures.append(temps)
      ent:messages := allMessages
      ent:seen := currentSeen
      schedule gossip event "heartbeat" at time:add(time:now(), {"seconds": ent:n})
    }
  }
  
  rule received_rumor {
    select when gossip rumor where ent:status == "on"
    pre {
      rumor = event:attr("rumor")
      isDup = checkDup(rumor)
    }
    
    if isDup then 
      send_directive("Duplicate message")
      
    notfired {
      ent:messages := ent:messages.defaultsTo([]).append(rumor)
      ent:seen := createSeen(ent:messages)
    }
  }
  
  rule received_seen {
    select when gossip seen where ent:status == "on"
    pre {
      theirRx = event:attr("theirRx")
      seen = event:attr("seen")
      notSeen = (ent:messages.isnull()) => [] | getNotSeen(ent:seen.defaultsTo([]), seen)
    }
    always {
      ent:othersSeen := ent:othersSeen.defaultsTo({}).set([theirRx], seen)
      raise gossip event "send_rumors"
        attributes { "Tx": theirRx, "notSeen": notSeen }
    }
  }
  
  
  rule send_rumors {
    select when gossip send_rumors
    foreach event:attr("notSeen") setting(rumor)
    event:send({"eci": event:attr("Tx"), "domain": "gossip", "type": "rumor", "attrs": { "rumor": rumor }})
  }
  
  rule gossip_startup {
    select when gossip startup
    pre {
      n = event:attr("n")
      temps = store:temperatures()
    }
    always {
      ent:messages := createMessages(temps)
      ent:temperatures := temps
      ent:seen := createSeen(ent:messages)
      ent:othersSeen := {}
      ent:status := "on"
      ent:n := n
      raise gossip event "heartbeat"
    }
  }
  
  
  rule gossip_status {
    select when gossip status where (event:attr("status") == "on" || event:attr("status") == "off")
    always {
      ent:status := event:attr("status")
      raise gossip event "heartbeat"
      if ent:status == "on"
    }
  }
  
  rule restart {
    select when gossip restart
    always {
      clear ent:temperatures
      clear ent:messages
      clear ent:seen
      clear ent:othersSeen
      clear ent:status
      clear ent:n
    }
  }
}
