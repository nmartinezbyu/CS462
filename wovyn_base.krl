ruleset wovyn_base {
  meta {
    shares __testing
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
    
    temperature_threshold = 80
  }
  
  rule process_heartbeat {
    select when wovyn heartbeat
    pre {
      time = time:now()
      temp = event:attr("genericThing")["data"]["temperature"][0]["temperatureF"]
      
    }
    if not event:attr("genericThing").isnull()
    then
    send_directive("say",{"Temperature": temp})
    
    fired {
      raise wovyn event "new_temperature_reading"
      attributes {"temperature":temp, "timestamp":time}
    }
  }
  
  rule find_high_temps {
    select when wovyn new_temperature_reading
    pre{
      temperature = event:attr("temperature")
      timestamp = event:attr("timestamp")
    }
    
    if event:attr("temperature") > temperature_threshold
    then 
    send_directive("say",{"something": "Temperature Violation!!!!"})
    fired {
          raise wovyn event "threshold_violation"
          attributes{"temperature":temperature, "timestamp":timestamp}
    }
  }
  
  rule threshold_notification {
    select when wovyn threshold_violation
    
    always {
      raise echo event "Messaging"
    }
  }
}
