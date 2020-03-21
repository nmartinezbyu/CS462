ruleset temperature_store {
  meta {
    provides temperatures, threshold_violations, inrange_temperatures
    shares temperatures, threshold_violations, inrange_temperatures, __testing
    use module io.picolabs.subscription alias subscription
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" }, {"name": "temperatures"}, {"name": "threshold_violations"}, {"name": "inrange_temperatures"}
      //, { "name": "entry", "args": [ "key" ] }
      ] , "events":
      [ //{ "domain": "d1", "type": "t1" }
      //, { "domain": "d2", "type": "t2", "attrs": [ "a1", "a2" ] }
      ]
    }
    
    temperatures = function() {
      ent:reading.defaultsTo([])
    }
    
    threshold_violations = function() {
      ent:violation.defaultsTo([])
    }
    
    inrange_temperatures = function() {
        ent:reading.difference(ent:violation)
    }
    subs = function(tx) {
      subscription:established("Tx", tx)[0]
    }
    
  }
  
  rule collect_temperatures {
    select when wovyn new_temperature_reading
    pre{
      map =  {"temperature":event:attr("temperature"), "timestamp":event:attr("timestamp")}
    }
    always{
      ent:reading := ent:reading.defaultsTo([]).append(map);
  
    }
  }
  
  rule collect_threshold_violations {
    select when wovyn threshold_violation
    pre{
      map =  {"temperature":event:attr("temperature"), "timestamp":event:attr("timestamp")}
    }
    always{
      ent:violation := ent:violation.defaultsTo([]).append(map);
    }
  }
  
  rule report_info {
    select when sensor report_temps
    pre{
      id = event:attr("id")
      Rx = event:attr("Rx");
      //originator = subs(managerRx);
      Tx = meta:eci 
      //originator{"Tx"}
      //sensorRx = originator{"Rx"}
      temperatures = temperatures()
    }
    event:send({
      "eci": Rx, "domain": "sensor", "type": "report_received", "attrs": {"Rx": Tx, "temperatures": temperatures, "id": id}
    })
  }
  
  rule clear_temperatures {
    select when sensor reading_reset
    always{
      clear ent:reading;
      clear ent:violation;
    }
  }
}
