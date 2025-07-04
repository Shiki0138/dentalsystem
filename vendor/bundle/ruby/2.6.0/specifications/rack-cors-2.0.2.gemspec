# -*- encoding: utf-8 -*-
# stub: rack-cors 2.0.2 ruby lib

Gem::Specification.new do |s|
  s.name = "rack-cors".freeze
  s.version = "2.0.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Calvin Yu".freeze]
  s.date = "2024-03-04"
  s.description = "Middleware that will make Rack-based apps CORS compatible. Fork the project here: https://github.com/cyu/rack-cors".freeze
  s.email = ["me@sourcebender.com".freeze]
  s.homepage = "https://github.com/cyu/rack-cors".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.0.3.1".freeze
  s.summary = "Middleware for enabling Cross-Origin Resource Sharing in Rack apps".freeze

  s.installed_by_version = "3.0.3.1" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rack>.freeze, [">= 2.0.0"])
      s.add_development_dependency(%q<bundler>.freeze, [">= 1.16.0", "< 3"])
      s.add_development_dependency(%q<minitest>.freeze, ["~> 5.11.0"])
      s.add_development_dependency(%q<mocha>.freeze, ["~> 1.6.0"])
      s.add_development_dependency(%q<pry>.freeze, ["~> 0.12"])
      s.add_development_dependency(%q<rack-test>.freeze, [">= 1.1.0"])
      s.add_development_dependency(%q<rake>.freeze, ["~> 12.3.0"])
      s.add_development_dependency(%q<rubocop>.freeze, ["~> 0.80.1"])
    else
      s.add_dependency(%q<rack>.freeze, [">= 2.0.0"])
      s.add_dependency(%q<bundler>.freeze, [">= 1.16.0", "< 3"])
      s.add_dependency(%q<minitest>.freeze, ["~> 5.11.0"])
      s.add_dependency(%q<mocha>.freeze, ["~> 1.6.0"])
      s.add_dependency(%q<pry>.freeze, ["~> 0.12"])
      s.add_dependency(%q<rack-test>.freeze, [">= 1.1.0"])
      s.add_dependency(%q<rake>.freeze, ["~> 12.3.0"])
      s.add_dependency(%q<rubocop>.freeze, ["~> 0.80.1"])
    end
  else
    s.add_dependency(%q<rack>.freeze, [">= 2.0.0"])
    s.add_dependency(%q<bundler>.freeze, [">= 1.16.0", "< 3"])
    s.add_dependency(%q<minitest>.freeze, ["~> 5.11.0"])
    s.add_dependency(%q<mocha>.freeze, ["~> 1.6.0"])
    s.add_dependency(%q<pry>.freeze, ["~> 0.12"])
    s.add_dependency(%q<rack-test>.freeze, [">= 1.1.0"])
    s.add_dependency(%q<rake>.freeze, ["~> 12.3.0"])
    s.add_dependency(%q<rubocop>.freeze, ["~> 0.80.1"])
  end
end
