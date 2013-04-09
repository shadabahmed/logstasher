# Logstasher - Awesome Logging for Rails [![Build Status](https://secure.travis-ci.org/shadabahmed/logstasher.png)](https://secure.travis-ci.org/shadabahmed/logstasher)

This gem is heavily inspired from [lograge](https://github.com/roidrage/lograge) but it's focused on one thing and one thing only; making your logs awesome.

How do I do that ?

Using these two awesome tools:
* [logstash](http://logstash.net) - Store and index your logs
* [Kibana](http://kibana.org/) - for awesome visualization. This is optional though, and you can use any other visualizer

## Installation

In your Gemfile:

    gem 'logstasher'

### Configure your \<environment\>.rb e.g. development.rb

    config.logstasher.enabled = true

    # This line is optional if you do not want to supress app logs in your <environment>.log
    config.logstasher.supress_app_log = false

## Adding custom fields to the log

Since some fields are very specific to your application for e.g. *user_name*, it is left upto you to add them. Here's how to add those to the logs:

    # In config/initializers/logstasher.rb

    if LogStasher.enabled
      LogStasher.add_custom_fields do |fields|
        fields[:user] = current_user && current_user.mail
        fields[:site] = request.path =~ /^\/api/ ? 'api' : 'user'

        # If you are using custom instrumentation, just add those to logstasher custom fields
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