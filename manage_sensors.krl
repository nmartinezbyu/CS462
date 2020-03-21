ruleset manage_sensors {
  meta {
    shares __testing, sensors, collectTemperatures, subs, getPicoName, getLatestReports
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias subscription
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" }, {"name": "sensors"}, {"name": "collectTemperatures"}, {"name": "subs"}, {"name": "getPicoName", "args":["eci"]}
      , { "name": "getLatestReports" }
      //, { "name": "entry", "args": [ "key" ] }
      ] , "events":
      [ { "domain": "sensor", "type": "new_sensor", "attrs": ["picoName"] }
      , { "domain": "sensor", "type": "unneeded_sensor", "attrs": [ "picoName", "id"] }
      , { "domain": "sensor", "type": "intro_sub", "attrs": [ "eci", "name", "Tx_role", "Rx_role", "channel_type", "Tx_host"] }
      , { "domain": "sensor", "type": "report" }
      //, { "domain": "d2", "type": "t2", "attrs": [ "a1", "a2" ] }
      ]
    }
    
    contains = function(name){
      ent:sensors{name}.isnull() => false | true
    }
    
    getPicoInfo = function(name) {
      eci = wrangler:children(name)[0].klog("at 0"){"eci"}
      id = wrangler:children(name)[0]{"id"}
      map = {"id": id, "eci": eci}.klog("map")
      map
    }
    
    sensors = function() {
      ent:sensors
    }
    
    collectTemperatures = function() {
      
      temperatures = subs().map(function(x){
        wrangler:skyQuery( x{"Tx"} , "temperature_store", "temperatures", {}, (x{"Tx_host"}) => x{"Tx_host"} | "http://localhost:8080")
      });
      temperatures
    }
    
    getPicoName = function(eci) {
        foundName = wrangler:children().filter(function(x){
          eci == x{"eci"}
        });
        foundName[0]{"name"};
    }
    
    subs = function() {
      subscription:established("Tx_role", "sensor")
    }
    
    addReportSensors = function(id) {
      report = ent:sensorReport
      updatedReport = (report.isnull()) => report.defaultsTo({}).put(id, {"temperature_sensors": 1, "responding": 0, "temperatures": []})
                      | (report{id}.isnull()) => report.put(id, {"temperature_sensors": 1, "responding": 0, "temperatures": []})
                      | report.set([id, "temperature_sensors"], report{id}{"temperature_sensors"} + 1)
      updatedReport
    }
    
    addTempToReport = function(id, rx, temps) {
      report = ent:sensorReport
      updatedReport = (report.isnull()) => report.defaultsTo({}).put(id, {"temperatures": [{}.put(rx, temps)]}) 
                      | report.set([id, "temperatures"], report{id}{"temperatures"}.append({}.put(rx, temps)))
      updatedRespondingReport = updatedReport.set([id, "responding"], updatedReport{id}{"temperatures"}.length().klog("length"))
      updatedRespondingReport
    }
    
    // getReport = function() {
    //   ent:sensorReport.defaultsTo([])
    // }
    
    storeId = function(id) {
      ent:allIds.defaultsTo([]).append(id)
    }
    
    getLatestReports = function() {
      allIds = ent:allIds.defaultsTo([])
      lastFiveIds = (allIds.length() > 5) => allIds.slice(allIds.length() - 5, allIds.length() - 1)
                  | allIds
      lastFiveReports = lastFiveIds.map(function(x){
        {}.put(x, ent:sensorReport{x})
      })
      
      lastFiveReports
    }
    
    
    default_threshold = 80
    default_phone = 9402307232
  }
  
  rule create_sensors {
    select when sensor new_sensor
    pre {
      picoName = event:attr("picoName")
    }
    
    if contains(picoName)
    then
      send_directive("There is already a Pico with that name")
    
    notfired {
      raise wrangler event "child_creation"
        attributes { "location":"PicoDesk1", "name":picoName, "phoneNum": default_phone, "threshold":default_threshold, "color": "#ffff00", "rids": ["temperature_store", "wovyn_base", "sensor_profile"]};
      raise sensor event "add_sensor_name"
        attributes {"picoName": picoName};
    }
  }
  
  rule sensor_created {
    select when wrangler child_initialized
    pre {
      location = event:attr("location")
      name = event:attr("name")
      phoneNum = event:attr("phoneNum")
      threshold = event:attr("threshold")
      eci = event:attr("eci")
    }
      
    event:send({"eci":eci, "domain":"sensor", "type":"profile_updated", "attrs":{"location": location, "name": name, "phoneNum": phoneNum, "threshold": threshold}})
    
    always {
        raise sensor event "subscribe"
          attributes {"picoName": name, "txRole": "sensor", "rxRole":"manager", "chanType": "subscription", "wellknown_Tx": eci};
    }
  }
  
  rule subscribe {
    select when sensor subscribe
    pre {
      name = event:attr("picoName")
      Tx_role = event:attr("txRole")
      Rx_role = event:attr("rxRole")
      channel_type = event:attr("chanType")
      wellKnown_Tx = event:attr("wellknown_Tx")
    }
    always
    {
      raise wrangler event "subscription" 
        attributes
          { "name" : name,
            "Tx_role": Tx_role,
            "Rx_role": Rx_role,
            "channel_type": channel_type,
            "wellKnown_Tx" : wellKnown_Tx
          }
    }
  }
  
  rule add_to_sublist {
    select when wrangler subscription_added
    pre {
      picoEci = event:attr("Tx")
      picoName = event:attr("name") || getPicoName(picoEci)
      Rx_role = event:attr("Rx_role")
      id = event:attr("Id")
      map = {"id": id, "eci":picoEci}
    }
    if Rx_role == "sensor" then
      send_directive("Adding to sublist")
    fired {
      ent:sublist := ent:sublist.defaultsTo({}).put(picoName, map);
    }
  }
  
  rule introduce_subscription {
    select when sensor intro_sub
    pre {
      wellKnown_Tx = event:attr("eci")
      name = event:attr("name")
      Tx_role = event:attr("Tx_role")
      Rx_role = event:attr("Rx_role")
      channel_type = event:attr("channel_type")
      Tx_host = (event:attr("Tx_host").isnull() || event:attr("Tx_host") == "" => null | event:attr("Tx_host"))
    }
    
    // event:send(
    //   { "eci": managerEci, "eid": "subscription",
    //     "domain": "wrangler", "type": "subscription",
    //     "attrs": { "name": name,
    //               "Tx_role": Tx_role,
    //               "Rx_role": Rx_role,
    //               "channel_type": channel_type,
    //               "wellKnown_Tx": sensor{"eci"} } } )
    always {
      raise wrangler event "subscription"
        attributes {"name": name,
                   "Tx_role": Tx_role,
                   "Rx_role": Rx_role,
                   "Tx_host": Tx_host,
                   "channel_type": channel_type,
                   "wellKnown_Tx": wellKnown_Tx}
    }
  }
  
  rule autoAccept {
    select when wrangler inbound_pending_subscription_added
    pre{
      attributes = event:attrs.klog("subcription :");
    }
    always{
      raise wrangler event "pending_subscription_approval"
        attributes attributes;       
      log info "auto accepted subcription.";
    }
  }
  
  
  rule delete_sensor {
    select when sensor unneeded_sensor
    pre {
      picoName = event:attr("picoName")
    }
    if contains(picoName)
    then
      send_directive("Deleting Pico")
    fired {
      raise wrangler event "child_deletion"
        attributes{"name": picoName, "id": ent:sensors{picoName}{"id"}};
      ent:sensors := ent:sensors.delete(picoName)
    }
  }
  
  rule add_name_to_list {
    select when sensor add_sensor_name
    pre {
      picoName =  event:attr("picoName")
      map = getPicoInfo(picoName)
      
    }
    always {
      ent:sensors := ent:sensors.defaultsTo({}).put(picoName, map);
    }
  }
  
  
  rule listen_for_violations {
    select when temperature threshold_violation
    always
    {
      raise notify event "send_msg"
    }
  }
  
  rule report {
    select when sensor report
    foreach subs() setting(sensor)
    pre {
      id = event:attr("id") || ent:currentReportId.defaultsTo(random:uuid())
    }
    event:send({"eci": sensor{"Tx"}.klog("The eci"), "domain": "sensor", "type": "report_temps", "attrs": {"id": id, "Rx": sensor{"Rx"}}})
    always {
      ent:sensorReport := addReportSensors(id)
      ent:currentReportId := id
      ent:currentReportId := null on final;
      ent:allIds := storeId(id) on final;
    }
  }
  
  rule receive_report {
    select when sensor report_received
    pre {
      theirRx = event:attr("Rx")
      temps = event:attr("temperatures")
      id = event:attr("id")
    }
    always {
      ent:sensorReport := addTempToReport(id, theirRx, temps)
    }
  }
  
}
