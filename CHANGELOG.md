# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- `require "fal-ai"` now works. Previously the gem only defined `lib/fal.rb`, so
  `require "fal-ai"` (what the README documents and what Bundler auto-requires for
  `gem "fal-ai"`) raised `LoadError`.

### Changed

- CI now tests against Ruby 3.3, 3.4, and 4.0 and runs on every pull request.
- `required_ruby_version` is now `>= 3.3`.
- `Gemfile.lock` is no longer committed (standard practice for libraries, so CI
  resolves against current dependency versions).

### Added

- GitHub project scaffolding: issue and pull request templates, Dependabot
  config, `CODEOWNERS`, and a trusted-publishing release workflow.

## [0.1.0] - 2025-12-05

### Added

- Initial release
- Synchronous `run` method for direct model inference
- Queue-based `subscribe` method with polling for long-running tasks
- Direct queue operations (`submit`, `status`, `result`)
- Support for all fal.ai models (Flux, Stable Diffusion, etc.)
- Configurable timeout and poll intervals
- Comprehensive error handling with typed exceptions
- Full test coverage
