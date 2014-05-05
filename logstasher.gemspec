# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "logstasher/version"

Gem::Specification.new do |s|
  s.name        = "logstasher"
  s.version     = LogStasher::VERSION
  s.authors     = ["Shadab Ahmed"]
  s.email       = ["shadab.ansari@gmail.com"]
  s.homepage    = "https://github.com/shadabahmed/logstasher"
  s.summary     = %q{Awesome rails logs}
  s.description = %q{Awesome rails logs}

  s.rubyforge_project = "logstasher"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  s.add_runtime_dependency "logstash-event", ["~> 1.1.0"]
  s.add_runtime_dependency "request_store"

  # specify any dependencies here; for example:
  s.add_development_dependency "rspec"
  s.add_development_dependency("bundler", [">= 1.0.0"])
  s.add_development_dependency("rails", [">= 3.0"])
end
