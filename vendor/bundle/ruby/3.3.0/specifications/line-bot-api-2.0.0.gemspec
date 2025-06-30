# -*- encoding: utf-8 -*-
# stub: line-bot-api 2.0.0 ruby lib

Gem::Specification.new do |s|
  s.name = "line-bot-api".freeze
  s.version = "2.0.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/line/line-bot-sdk-ruby/issues", "changelog_uri" => "https://github.com/line/line-bot-sdk-ruby/releases", "documentation_uri" => "https://rubydoc.info/gems/line-bot-api/2.0.0", "homepage_uri" => "https://github.com/line/line-bot-sdk-ruby", "source_code_uri" => "https://github.com/line/line-bot-sdk-ruby" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["LINE Corporation".freeze]
  s.date = "2025-05-12"
  s.description = "SDK of the LINE Messaging API for Ruby".freeze
  s.homepage = "https://github.com/line/line-bot-sdk-ruby".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.2.0".freeze)
  s.rubygems_version = "3.5.22".freeze
  s.summary = "SDK of the LINE Messaging API for Ruby".freeze

  s.installed_by_version = "3.5.22".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<multipart-post>.freeze, ["~> 2.4".freeze])
  s.add_runtime_dependency(%q<base64>.freeze, ["~> 0.2".freeze])
end
