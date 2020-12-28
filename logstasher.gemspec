# frozen_string_literal: true

require './lib/logstasher/version'

Gem::Specification.new do |s|
  s.name        = 'logstasher'
  s.version     = LogStasher::VERSION
  s.authors     = ['Shadab Ahmed']
  s.email       = ['shadab.ansari@gmail.com']
  s.homepage    = 'https://github.com/shadabahmed/logstasher'
  s.summary     = s.description = 'Awesome rails logs'
  s.license     = 'MIT'

  s.files = `git ls-files lib`.split("\n")

  s.add_runtime_dependency 'activesupport', '>= 5.2'
  s.add_runtime_dependency 'request_store'

  s.add_development_dependency('bundler', '>= 1.0.0')
  s.add_development_dependency('rails', '>= 5.2')
  s.add_development_dependency('rspec', '>= 2.14')
end
