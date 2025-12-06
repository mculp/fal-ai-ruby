# frozen_string_literal: true

require_relative "lib/fal/version"

Gem::Specification.new do |spec|
  spec.name = "fal-ai"
  spec.version = Fal::VERSION
  spec.authors = ["Matt Culpepper"]
  spec.email = ["matt@culpepper.co"]

  spec.summary = "Ruby client for fal.ai generative AI platform"
  spec.description = "A Ruby client library for fal.ai's generative AI platform. " \
                     "Run inference on 600+ AI models including Flux, Stable Diffusion, " \
                     "and more with synchronous and queue-based APIs."
  spec.homepage = "https://github.com/mculp/fal-ai-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = "https://fal.ai"
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/mculp/fal-ai-ruby/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://rubydoc.info/gems/fal-ai"
  spec.metadata["bug_tracker_uri"] = "https://github.com/mculp/fal-ai-ruby/issues"
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
