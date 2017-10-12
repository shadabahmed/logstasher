# Logstasher [![Gem Version](https://badge.fury.io/rb/logstasher.svg)](https://badge.fury.io/rb/logstasher) [![Build Status](https://travis-ci.org/shadabahmed/logstasher.svg?branch=master)](https://secure.travis-ci.org/shadabahmed/logstasher)
### Awesome Logging for Rails !!

This gem is heavily inspired from [lograge](https://github.com/roidrage/lograge), but it's focused on one thing and one thing only. That's making your logs awesome like this:

[![Awesome Logs](https://f.cloud.github.com/assets/830679/2407078/dcde03e8-aa82-11e3-85ac-8c5b3a86676e.png)](https://f.cloud.github.com/assets/830679/2407078/dcde03e8-aa82-11e3-85ac-8c5b3a86676e.png)

How it's done ?

By, using these awesome tools:
* [Logstash](http://logstash.net) - Store and index your logs
* [Kibana](http://kibana.org/) - for awesome visualization. This is optional though, and you can use any other visualizer

Update: Logstash now includes Kibana build in, so no need to separately install. Logstasher has been tested with **logstash version 1.4.2** with `file input` and `json codec`.

See [quickstart](#quick-setup-for-logstash) for quickly setting up logstash

## About logstasher

This gem purely focuses on how to generate logstash compatible logs i.e. *logstash json event format*,  without any overhead. Infact, logstasher logs to a separate log file named `logstash_<environment>.log`.
The reason for this separation:
 * To have a pure json log file
 * Prevent any logger messages(e.g. info) getting into our pure json logs

Before **logstasher** :

```
Started GET "/login" for 10.109.10.135 at 2013-04-30 08:59:01 -0400
Processing by SessionsController#new as HTML
[ActiveJob] [TestJob] [61d6e87a-875d-4255-9424-cab7d5ff208c] Performing TestJob from Test(default) with arguments: 0, 1
  Rendered sessions/new.html.haml within layouts/application (4.3ms)
  Rendered shared/_javascript.html.haml (0.6ms)
  Rendered shared/_flashes.html.haml (0.2ms)
  Rendered shared/_header.html.haml (52.9ms)
  Rendered shared/_title.html.haml (0.2ms)
  Rendered shared/_footer.html.haml (0.2ms)
Completed 200 OK in 532ms (Views: 62.4ms | ActiveRecord: 0.0ms | ND API: 0.0ms)
```

After **logstasher**:

```json
{"job_id":"61d6e87a-875d-4255-9424-cab7d5ff208c","queue_name":"Test(default)","job_class":"ExampleJob","job_args":[1,0],
"exception":["ZeroDivisionError","divided by 0"],"duration":3.07,"request_id":"61d6e87a-875d-4255-9424-cab7d5ff208c",
"source":"unknown","tags":["job","perform","exception"],"@timestamp":"2016-03-29T16:14:32.837Z","@version":"1"}

{"@source":"unknown","@tags":["request"],"@fields":{"method":"GET","path":"/","format":"html","controller":"file_servers"
,"action":"index","status":200,"duration":28.34,"view":25.96,"db":0.88,"ip":"127.0.0.1","route":"file_servers#index",
"parameters":"","ndapi_time":null,"uuid":"e81ecd178ed3b591099f4d489760dfb6","user":"shadab_ahmed@abc.com",
"site":"internal"},"@timestamp":"2013-04-30T13:00:46.354500+00:00"}
```

By default, the older format rails request logs are disabled, though you can enable them.

## Installation

In your Gemfile:
```ruby
gem 'logstasher'
```

### Configure your `<environment>.rb` e.g. `development.rb`
```ruby
# Enable the logstasher logs for the current environment
config.logstasher.enabled = true

# Each of the following lines are optional. If you want to selectively disable log subscribers.
config.logstasher.controller_enabled = false
config.logstasher.mailer_enabled = false
config.logstasher.record_enabled = false
config.logstasher.view_enabled = false
config.logstasher.job_enabled = false

# This line is optional if you do not want to suppress app logs in your <environment>.log
config.logstasher.suppress_app_log = false

# This line is optional, it allows you to set a custom value for the @source field of the log event
config.logstasher.source = 'your.arbitrary.source'

# This line is optional if you do not want to log the backtrace of exceptions
config.logstasher.backtrace = false

# This line is optional, defaults to log/logstasher_<environment>.log
config.logstasher.logger_path = 'log/logstasher.log'

# This line is optional, loaded only if the value is truthy
config.logstasher.field_renaming = {
    old_field_name => new_field_name,
}

```

## Optionally use config/logstasher.yml (overrides `<environment>.rb`)

Has the same optional fields as the `<environment>.rb`. You can specify common configurations that are then overriden by environment specific configurations:
```yml
controller_enabled: true
mailer_enabled: false
record_enabled: false
job_enabled: false
view_enabled: true
suppress_app_log: false
development:
  enabled: true
  record_enabled: true
production:
  enabled: true
  mailer_enabled: true
  view_enabled: false
```
## Logging params hash

Logstasher can be configured to log the contents of the params hash.  When enabled, the contents of the params hash (minus the ActionController internal params)
will be added to the log as a deep hash.  This can cause conflicts within the Elasticsearch mappings though, so should be enabled with care.  Conflicts will occur
if different actions (or even different applications logging to the same Elasticsearch cluster) use the same params key, but with a different data type (e.g. a
string vs. a hash).  This can lead to lost log entries.  Enabling this can also significantly increase the size of the Elasticsearch indexes.

To enable this, add the following to your `<environment>.rb`
```ruby
# Enable logging of controller params
config.logstasher.log_controller_parameters = true
```

## Adding custom fields to the log

Since some fields are very specific to your application for e.g. *user_name*, so it is left upto you, to add them. Here's how to add those fields to the logs:
```ruby
# Create a file - config/initializers/logstasher.rb

if LogStasher.enabled?
  LogStasher.add_custom_fields do |fields|
    # This block is run in application_controller context,
    # so you have access to all controller methods
    fields[:user] = current_user && current_user.mail
    fields[:site] = request.path =~ /^\/api/ ? 'api' : 'user'

    # If you are using custom instrumentation, just add it to logstasher custom fields
    LogStasher.custom_fields << :myapi_runtime
  end

  LogStasher.add_custom_fields_to_request_context do |fields|
    # This block is run in application_controller context,
    # so you have access to all controller methods
    # You can log custom request fields using this block
    fields[:user] = current_user && current_user.mail
    fields[:site] = request.path =~ /^\/api/ ? 'api' : 'user'
  end
end
```
## Logging ActionMailer events

Logstasher can easily log messages from `ActionMailer`, such as incoming/outgoing e-mails and e-mail content generation (Rails >= 4.1).
This functionality is automatically enabled. Since the relationship between a concrete HTTP request and a mailer invocation is lost
once in an `ActionMailer` instance method, global (per-request) state is kept to correlate HTTP requests and events from other parts
of rails, such as `ActionMailer`. Every time a request is invoked, a `request_id` key is added which is present on every `ActionMailer` event.

Note: Since mailers are executed within the lifetime of a request, they will show up in logs prior to the actual request.

## Logging ActiveJob events

Logstasher can also easily log messages from `ActiveJob` (Rails >= 4.2).
This functionality is automatically enabled. The `request_id` is set to the Job ID when the job is
performed, and then reverted back to its previous value once the job is complete. Imagine this
scenario:

* Web request starts (sets `request_id` to some value)
* Job is enqueued because of the web request (the same web `request_id` is used)
* Job is performing starts (pretend non-asynchronous adapter or perform_now was used)
* `request_id` is set to the job id. This is important because for asynchronous jobs, there's no way
  to remember the original `request_id`
* Now, you can add your own detailed logging to the job, and the `request_id` can be used
* Once the job completes, the `request_id` is reverted and other SQL and View log lines will use
  that same old `request_id` again.

## Listening to `ActiveSupport::Notifications` events

It is possible to listen to any `ActiveSupport::Notifications` events and store arbitrary data to be included in the final JSON log entry:
```ruby
# In config/initializers/logstasher.rb

# Watch calls the block with the same arguments than any ActiveSupport::Notification, plus a store
LogStasher.watch('some.activesupport.notification') do |name, start, finish, id, payload, store|
  # Do something
  store[:count] = 42
end
```

Would change the log entry to:

```json
{"@source":"unknown","@tags":["request"],"@fields":{"method":"GET","path":"/","format":"html","controller":"file_servers","action":"index","status":200,"duration":28.34,"view":25.96,"db":0.88,"ip":"127.0.0.1","route":"file_servers#index", "parameters":"","ndapi_time":null,"uuid":"e81ecd178ed3b591099f4d489760dfb6","user":"shadab_ahmed@abc.com", "site":"internal","some.activesupport.notification":{"count":42}},"@timestamp":"2013-04-30T13:00:46.354500+00:00"}
```

The store exposed to the blocked passed to `watch` is thread-safe, and reset after each request.
By default, the store is only shared between occurences of the same event.
You can easily share the same store between different types of notifications, by assigning them to the same event group:

```ruby
# In config/initializers/logstasher.rb

LogStasher.watch('foo.notification', event_group: 'notification') do |*args, store|
  # Shared store with 'bar.notification'
end

LogStasher.watch('bar.notification', event_group: 'notification') do |*args, store|
  # Shared store with 'foo.notification'
end
```

## Quick Setup for Logstash

Follow the instructions at [logstash documentation](https://www.elastic.co/guide/en/logstash/index.html) to setup logstash.
Start logstash with the following command:
```
bin/logstash -f quickstart.conf
```

## Versions
All versions require Rails 3.0.x and higher and Ruby 1.9.2+. Tested on Rails 4 and Ruby 2.0

## Development
 - Install dependencies:
   export RAILS_VERSION=4.2
   bundle install --without guard --path=${BUNDLE_PATH:-vendor/bundle}
 - Run tests - `rake`
 - Generate test coverage report - `rake coverage`. Coverage report path - coverage/index.html

## Copyright

Copyright (c) 2016 Shadab Ahmed, released under the MIT license
