ruleset TwilioModule {
  meta {
    shares __testing, getMessages
    configure using accountSID = "" authToken = ""
    provide sendMSG, getMessages
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" }, { "name": "getMessages", "args": [ "toPhone", "fromPhone", "pagination" ] }
      //, { "name": "entry", "args": [ "key" ] }
      ] , "events":
      [ //{ "domain": "d1", "type": "t1" }
      //, { "domain": "d2", "type": "t2", "attrs": [ "a1", "a2" ] }
      ]
    }
    
    getMessages = function(toPhone, fromPhone, pagination)
    {
      messages = http:get(<<https://#{accountSID}:#{authToken}@api.twilio.com/2010-04-01/Accounts/#{accountSID}/Messages.json>>, parseJSON=true)["content"]["messages"];
      retrieve = messages.map(function(message){
        to = message["to"];
        from = message["from"];
        body = message["body"];
        
        {"to" : to, "from" : from, "body" : body}
      }).klog("retrieve");
      
      firstFilter = (toPhone.isnull() || toPhone == "" => retrieve | retrieve.filter(function(x){
        x["to"] == ("+1"+toPhone)
      })).klog("first");

      secondFilter = fromPhone.isnull() || fromPhone == "" => firstFilter | firstFilter.filter(function(x){
        x["from"] == ("+1"+fromPhone)
      });
      
      filteredMessages = pagination.isnull() || pagination == "" || pagination < 1  => secondFilter | secondFilter.slice(0, ( pagination > secondFilter.length() => secondFilter.length() - 1 | pagination - 1));
      
      filteredMessages
    }
    
    sendMSG = defaction(toPhone, fromPhone) {
          http:post(<<https://#{accountSID}:#{authToken}@api.twilio.com/2010-04-01/Accounts/#{accountSID}/Messages.json>>, form = {
            "From": fromPhone,
            "Body": "Temperature Violation!!!",
            "To": toPhone
          })
    }
  }

}
