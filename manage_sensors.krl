ruleset manage_sensors {
  meta {
    shares __testing, sensors, collectTemperatures
    use module io.picolabs.wrangler alias wrangler
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" }, {"name": "sensors"}, {"name": "collectTemperatures"}
      //, { "name": "entry", "args": [ "key" ] }
      ] , "events":
      [ { "domain": "sensor", "type": "new_sensor", "attrs": ["picoName"] }
      , { "domain": "sensor", "type": "unneeded_sensor", "attrs": [ "picoName", "id"] }
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
      temperatures = ent:sensors.map(function(x){
        wrangler:skyQuery( x{"eci"} , "temperature_store", "temperatures")
      });
      temperatures
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
      raise echo event "add_sensor_name"
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
    select when echo add_sensor_name
    pre {
      picoName =  event:attr("picoName")
      map = getPicoInfo(picoName)
      
    }
    always {
    ent:sensors := ent:sensors.defaultsTo({}).put(picoName, map);
    //ent:sublist := ent:sublist.defaultsTo([]).append(map);//You added this for lab 9
    }
  }
  
}
