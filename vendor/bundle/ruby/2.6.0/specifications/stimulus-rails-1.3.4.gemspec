# -*- encoding: utf-8 -*-
# stub: stimulus-rails 1.3.4 ruby lib

Gem::Specification.new do |s|
  s.name = "stimulus-rails".freeze
  s.version = "1.3.4"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "homepage_uri" => "https://stimulus.hotwired.dev", "source_code_uri" => "https://github.com/hotwired/stimulus-rails" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Sam Stephenson".freeze, "Javan Mahkmali".freeze, "David Heinemeier Hansson".freeze]
  s.date = "2024-08-16"
  s.email = "david@loudthinking.com".freeze
  s.homepage = "https://stimulus.hotwired.dev".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.0.3.1".freeze
  s.summary = "A modest JavaScript framework for the HTML you already have.".freeze

  s.installed_by_version = "3.0.3.1" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<railties>.freeze, [">= 6.0.0"])
    else
      s.add_dependency(%q<railties>.freeze, [">= 6.0.0"])
    end
  else
    s.add_dependency(%q<railties>.freeze, [">= 6.0.0"])
  end
end
