ruleset wovyn_base {
  meta {
    shares __testing
    use module sensor_profile alias sp
    use module io.picolabs.subscription alias subscription
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" }
      //, { "name": "entry", "args": [ "key" ] }
      ] , "events":
      [ { "domain": "wovyn", "type": "heartbeat"}
      //, { "domain": "d2", "type": "t2", "attrs": [ "a1", "a2" ] }
      ]
    }
    
    getRecepeints = function() {
       subscription:established().filter(function(x){
         x{"Tx_role"} == "manager" 
       }).map(function(x){
         x{"Tx"}
       })
    }
    
  }
  
  rule process_heartbeat {
    select when wovyn heartbeat where event:attr("genericThing")
    pre {
      time = time:now()
      temp = event:attr("genericThing")["data"]["temperature"][0]["temperatureF"]
    }
    
    send_directive("say",{"Temperature": temp})
    
    always {
      raise wovyn event "new_temperature_reading"
      attributes {"temperature":temp, "timestamp":time}
    }
  }
  
  rule find_high_temps {
    select when wovyn new_temperature_reading
    pre{
      temperature = event:attr("temperature")
      timestamp = event:attr("timestamp")
      recepeints = getRecepeints()
      message = (temperature.klog("temp") > sp:setThreshold().klog("threshold")) => "Temperature Violation!!!!" | "You good"
    }
    send_directive("say",{"something": message})
    always {
          raise wovyn event "threshold_violation"
          attributes{"temperature":temperature, "timestamp":timestamp, "receipeints": recepeints}
          if temperature > sp:setThreshold()
    }
  }
  
  rule threshold_notification {
    select when wovyn threshold_violation
    foreach event:attr("receipeints") setting (e)
    
    event:send({"eci":e, "domain":"temperature", "type":"threshold_violation"})
    
    // always {
    //   raise echo event "Messaging"
    //   attributes{"toPhone": sp:setPhone()}
    // }
  }
}
