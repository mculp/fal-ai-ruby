# frozen_string_literal: true

require_relative "lib/fal/version"

Gem::Specification.new do |spec|
  spec.name = "fal"
  spec.version = Fal::VERSION
  spec.authors = ["fal.ai"]
  spec.email = ["support@fal.ai"]

  spec.summary = "Ruby client for fal.ai Model APIs"
  spec.description = "A Ruby client library for interacting with fal.ai's Model APIs. " \
                     "Provides synchronous and queue-based access to 600+ AI models."
  spec.homepage = "https://github.com/fal-ai/fal-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/fal-ai/fal-ruby"
  spec.metadata["changelog_uri"] = "https://github.com/fal-ai/fal-ruby/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "http", "~> 5.0"
end
