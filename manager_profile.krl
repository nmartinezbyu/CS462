ruleset manager_profile {
  meta {
    shares __testing
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" }
      //, { "name": "entry", "args": [ "key" ] }
      ] , "events":
      [ //{ "domain": "d1", "type": "t1" }
      //, { "domain": "d2", "type": "t2", "attrs": [ "a1", "a2" ] }
      ]
    }
    
    sms_notification_num = 9402307232
  }
  
  rule set_manager_number {
    select when wrangler ruleset_added where event:attr("rids") >< "manager_profile"
    always {
      ent:phoneNum := sms_notification_num
    }
  }
  
  rule send_msg {
    select when notify send_msg
    always{
      raise echo event "Messaging"
        attributes {"toPhone": ent:phoneNum}
    }
  }
}
