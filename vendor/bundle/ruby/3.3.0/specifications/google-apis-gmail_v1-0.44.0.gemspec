# -*- encoding: utf-8 -*-
# stub: google-apis-gmail_v1 0.44.0 ruby lib

Gem::Specification.new do |s|
  s.name = "google-apis-gmail_v1".freeze
  s.version = "0.44.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/googleapis/google-api-ruby-client/issues", "changelog_uri" => "https://github.com/googleapis/google-api-ruby-client/tree/main/generated/google-apis-gmail_v1/CHANGELOG.md", "documentation_uri" => "https://googleapis.dev/ruby/google-apis-gmail_v1/v0.44.0", "source_code_uri" => "https://github.com/googleapis/google-api-ruby-client/tree/main/generated/google-apis-gmail_v1" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Google LLC".freeze]
  s.date = "1980-01-02"
  s.description = "This is the simple REST client for Gmail API V1. Simple REST clients are Ruby client libraries that provide access to Google services via their HTTP REST API endpoints. These libraries are generated and updated automatically based on the discovery documents published by the service, and they handle most concerns such as authentication, pagination, retry, timeouts, and logging. You can use this client to access the Gmail API, but note that some services may provide a separate modern client that is easier to use.".freeze
  s.email = "googleapis-packages@google.com".freeze
  s.homepage = "https://github.com/google/google-api-ruby-client".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.1".freeze)
  s.rubygems_version = "3.6.9".freeze
  s.summary = "Simple REST client for Gmail API V1".freeze

  s.installed_by_version = "3.5.22".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<google-apis-core>.freeze, [">= 0.15.0".freeze, "< 2.a".freeze])
end
