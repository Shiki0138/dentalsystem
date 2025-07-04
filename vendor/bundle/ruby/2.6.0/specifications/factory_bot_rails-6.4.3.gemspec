# -*- encoding: utf-8 -*-
# stub: factory_bot_rails 6.4.3 ruby lib

Gem::Specification.new do |s|
  s.name = "factory_bot_rails".freeze
  s.version = "6.4.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "changelog_uri" => "https://github.com/thoughtbot/factory_bot_rails/blob/main/NEWS.md" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Joe Ferris".freeze]
  s.date = "2023-12-30"
  s.description = "factory_bot_rails provides integration between factory_bot and rails 5.0 or newer".freeze
  s.email = "jferris@thoughtbot.com".freeze
  s.homepage = "https://github.com/thoughtbot/factory_bot_rails".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.0.3.1".freeze
  s.summary = "factory_bot_rails provides integration between factory_bot and rails 5.0 or newer".freeze

  s.installed_by_version = "3.0.3.1" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<factory_bot>.freeze, ["~> 6.4"])
      s.add_runtime_dependency(%q<railties>.freeze, [">= 5.0.0"])
      s.add_development_dependency(%q<sqlite3>.freeze, [">= 0"])
      s.add_development_dependency(%q<activerecord>.freeze, [">= 5.0.0"])
    else
      s.add_dependency(%q<factory_bot>.freeze, ["~> 6.4"])
      s.add_dependency(%q<railties>.freeze, [">= 5.0.0"])
      s.add_dependency(%q<sqlite3>.freeze, [">= 0"])
      s.add_dependency(%q<activerecord>.freeze, [">= 5.0.0"])
    end
  else
    s.add_dependency(%q<factory_bot>.freeze, ["~> 6.4"])
    s.add_dependency(%q<railties>.freeze, [">= 5.0.0"])
    s.add_dependency(%q<sqlite3>.freeze, [">= 0"])
    s.add_dependency(%q<activerecord>.freeze, [">= 5.0.0"])
  end
end
