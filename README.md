# Logstasher - Awesome Logging for Rails [![Build Status](https://secure.travis-ci.org/shadabahmed/logstasher.png)](https://secure.travis-ci.org/shadabahmed/logstasher)

This gem is heavily inspired from [lograge](https://github.com/roidrage/lograge) but it's focused on one thing and one thing only. That's making your logs awesome like this:

[![Awesome Logs](http://i.imgur.com/zZXWQNp.png)](http://i.imgur.com/zZXWQNp.png)

How it's done ?

By, using these awesome tools:
* [Logstash](http://logstash.net) - Store and index your logs
* [Kibana](http://kibana.org/) - for awesome visualization. This is optional though, and you can use any other visualizer

To know how to setup these tools - visit my [blog](http://shadabahmed.com/blog/2013/04/30/logstasher-for-awesome-rails-logging)

## About logstasher

This gem purely focuses on how to generate logstash compatible logs i.e. *logstash json event format*,  without any overhead. Infact, logstasher logs to a separate log file named `logstash_<environment>.log`.
The reason for this separation:
 * To have a pure json log file
 * Prevent any logger messages(e.g. info) getting into our pure json logs

Before **logstasher** :

```
Started GET "/login" for 10.109.10.135 at 2013-04-30 08:59:01 -0400
Processing by SessionsController#new as HTML
  Rendered sessions/new.html.haml within layouts/application (4.3ms)
  Rendered shared/_javascript.html.haml (0.6ms)
  Rendered shared/_flashes.html.haml (0.2ms)
  Rendered shared/_header.html.haml (52.9ms)
  Rendered shared/_title.html.haml (0.2ms)
  Rendered shared/_footer.html.haml (0.2ms)
Completed 200 OK in 532ms (Views: 62.4ms | ActiveRecord: 0.0ms | ND API: 0.0ms)
```

After **logstasher**:

```
{"@source":"unknown","@tags":["request"],"@fields":{"method":"GET","path":"/","format":"html","controller":"file_servers"
,"action":"index","status":200,"duration":28.34,"view":25.96,"db":0.88,"ip":"127.0.0.1","route":"file_servers#index",
"parameters":"","ndapi_time":null,"uuid":"e81ecd178ed3b591099f4d489760dfb6","user":"shadab_ahmed@abc.com",
"site":"internal"},"@timestamp":"2013-04-30T13:00:46.354500+00:00"}
```

By default, the older format rails request logs are disabled, though you can enable them.

## Installation

In your Gemfile:

    gem 'logstasher'

### Configure your `<environment>.rb` e.g. `development.rb`

    # Enable the logstasher logs for the current environment
    config.logstasher.enabled = true

    # This line is optional if you do not want to supress app logs in your <environment>.log
    config.logstasher.supress_app_log = false

## Adding custom fields to the log

Since some fields are very specific to your application for e.g. *user_name*, so it is left upto you, to add them. Here's how to add those fields to the logs:

    # Create a file - config/initializers/logstasher.rb

    if LogStasher.enabled
      LogStasher.add_custom_fields do |fields|
        fields[:user] = current_user && current_user.mail
        fields[:site] = request.path =~ /^\/api/ ? 'api' : 'user'

        # If you are using custom instrumentation, just add it to logstasher custom fields
        LogStasher.custom_fields << :myapi_runtime
      end
    end

## Versions
All versions require Rails 3.0.x and higher and Ruby 1.9.2+

## Development
 - Run tests - `rake`
 - Generate test coverage report - `rake coverage`. Coverage report path - coverage/index.html

## Copyright

Copyright (c) 2013 Shadab Ahmed, released under the MIT license
