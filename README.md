# Logstasher

**Awesome Logging for Rails**

## History

This is a fork of
[shadabahmed/logstasher](https://github.com/shadabahmed/logstasher). It has
been updated to use the [latest event
schema](https://logstash.jira.com/browse/LOGSTASH-675) and customized to better
fit the needs of MoneyDesktop--though it is still generally useful. It is not
backward compatible with its progenitor.

## Purpose

This gem makes it easy to generate logstash compatible logs for your rails app.

A request that looks like this in your `production.log`:
```text
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

Will look like this in your `logstash_production.log`:
```json
{"tags":["request"],"method":"GET","path":"/","format":"html","controller":"file_servers"
,"action":"index","status":200,"duration":28.34,"view":25.96,"db":0.88,"ip":"127.0.0.1","route":"file_servers#index",
"parameters":"","ndapi_time":null,"uuid":"e81ecd178ed3b591099f4d489760dfb6","user":"shadab_ahmed@abc.com",
"site":"internal","@timestamp":"2013-04-30T13:00:46.354500+00:00","@version":"1"}
```

From there, it's trivial to forward them to your logstash indexer. You can even
use the included redis log device to send the logs directly to a redis broker
instead.

## Installation

In your Gemfile:

    gem 'md-logstasher'

### Configure your `<environment>.rb` e.g. `development.rb`

    # Enable the logstasher logs for the current environment
    config.logstasher.enabled = true

    # Optionally silience the standard logging to <environment>.log
    config.logstasher.silence_standard_logging = true

## Logging params

By default, Logstasher will add params as a JSON encoded string. To disable,
add the following to your `<environment>.rb`

    # Disable logging of request parameters
    config.logstasher.include_parameters = false
    
## Adding custom fields to the log

Since some fields are very specific to your application, e.g., *user_name*,
it is left upto you to add them. Here's how to do it:

    # Create a file - config/initializers/logstasher.rb

    if LogStasher.enabled
      LogStasher.append_fields do |fields|
        # This block is run in application_controller context,
        # so you have access to all controller methods
        fields[:user] = current_user && current_user.mail
        fields[:site] = request.path =~ /^\/api/ ? 'api' : 'user'
      end
    end

## Versions
All versions require Rails 3.0.x and higher and Ruby 1.9.2+. Tested on Rails 4
and Ruby 2.0

## Development
 - Run tests - `rake`

## Copyright

Copyright (c) 2014 Shadab Ahmed, released under the MIT license
