ruleset hello_world {
  meta {
    name "Hello World"
    description <<
A first ruleset for the Quickstart
>>
    author "Phil Windley"
    logging on
    shares hello, __testing
  }

  global {
    __testing = { "queries": [ { "name": "hello", "args": [ "obj" ] },
                           { "name": "__testing" } ],
              "events": [ { "domain": "echo", "type": "monkey" , "attrs" : ["name"]}]
            }

    hello = function(obj) {
      msg = "Hello " + obj;
      msg
    }

  }

  rule hello_world {
    select when echo hello
    send_directive("say", {"something": "Hello World"})
  }

  rule monkey {
    select when echo monkey
    pre {
     //name = event:attr("name").defaultsTo("Monkey").klog("Hottest man alive: ")
      name = (event:attr("name").isnull() || event:attr("name") == "") => "Monkey" | event:attr("name")

    }
    send_directive("say", {"something": "Hello " + name})
  }
}
