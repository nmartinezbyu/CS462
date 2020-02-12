ruleset temperature_store {
  meta {
    provides temperatures, threshold_violations, inrange_temperatures
    shares temperatures, threshold_violations, inrange_temperatures, __testing
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
      ent:reading
    }
    
    threshold_violations = function() {
      ent:violation  
    }
    
    inrange_temperatures = function() {
        ent:reading.difference(ent:violation)
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
  
  rule clear_temperatures {
    select when sensor reading_reset
    always{
      clear ent:reading;
      clear end:violation;
    }
  }
}
