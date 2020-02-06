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
    phone = 9402307232
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
      message = (temperature > temperature_threshold) => "Temperature Violation!!!!" | "You good"
    }
    send_directive("say",{"something": message})
    always {
          raise wovyn event "threshold_violation"
          attributes{"temperature":temperature, "timestamp":timestamp}
          if temperature > temperature_threshold
    }
  }
  
  rule threshold_notification {
    select when wovyn threshold_violation
    
    always {
      raise echo event "Messaging"
      attributes{"toPhone": phone}
    }
  }
}
