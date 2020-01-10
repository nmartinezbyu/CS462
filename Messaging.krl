ruleset Messaging {
  meta {
    name "Messaging"
    description <<
A ruleset for sending and retrieving Text Messages, the Messaging rule works and can send an message but I am still working on retrieving messages.
>>
    shares __testing, getMessages
    use module TwilioKeys
    use module TwilioModule alias tm with
        accountSID = keys:twilio_keys{"sid"} and    
        authToken = keys:twilio_keys{"token"}
  }
  
  global {
    __testing = { "queries":
      [ { "name": "__testing" }
      , { "name": "getMessages", "args": [ "toPhone", "fromPhone", "pagination" ] }
      ] , "events":
      [ { "domain": "echo", "type": "Messaging", "attrs": ["toPhone", "fromPhone"] }
      //, { "domain": "d2", "type": "t2", "attrs": [ "a1", "a2" ] }
      ]
    }
    
    getMessages = function(toPhone, fromPhone, pagination) {
      tm:getMessages(toPhone, fromPhone, pagination)
    }
  }
  
  rule Messaging {
    select when echo Messaging where event:attr("fromPhone")

    pre {
        toPhone = (event:attr("toPhone").isnull() || event:attr("toPhone") == "") => 9402307232 | event:attr("toPhone") //You can default the toPhone number
        fromPhone = (event:attr("fromPhone").isnull() || event:attr("fromPhone") == "") => 9405148665 | event:attr("fromPhone") //You can default the toPhone number
    }
    tm:sendMSG(toPhone, fromPhone)
  }
}
