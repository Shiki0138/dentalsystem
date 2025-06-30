# -*- encoding: utf-8 -*-
# stub: rspec-activejob 0.6.1 ruby lib

Gem::Specification.new do |s|
  s.name = "rspec-activejob".freeze
  s.version = "0.6.1".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Isaac Seymour".freeze]
  s.date = "2015-10-20"
  s.description = "    RSpec matchers for ActiveJob:\n    * expect { method }.to enqueue_a(MyJob).with(global_id(some_model),\n                                                 deserialize_as(other_argument))\n".freeze
  s.email = ["isaac@isaacseymour.co.uk".freeze]
  s.homepage = "http://github.com/gocardless/rspec-activejob".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "2.4.5.1".freeze
  s.summary = "RSpec matchers to test ActiveJob".freeze

  s.installed_by_version = "3.5.22".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<activejob>.freeze, [">= 4.2".freeze])
  s.add_runtime_dependency(%q<rspec-mocks>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rspec>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rspec-its>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<activesupport>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rubocop>.freeze, [">= 0".freeze])
end
