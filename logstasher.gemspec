# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "logstasher/version"

Gem::Specification.new do |s|
  s.name        = "logstasher"
  s.version     = Logstasher::VERSION
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
  s.add_runtime_dependency "logstash-event"

  # specify any dependencies here; for example:
  s.add_development_dependency "rspec"
  s.add_development_dependency "guard-rspec"
  s.add_runtime_dependency "activesupport"
  s.add_runtime_dependency "actionpack"
end
