# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2026-06-06

This release brings the gem to feature parity with the official fal clients for
the Model API: streaming, file uploads, the full queue lifecycle, webhooks, and
module-level conveniences.

### Added

- `Client#stream` / `Fal.stream` — consume Server-Sent Events from streaming
  models, yielding each event and returning the final result. Backed by a small
  incremental `Sse::Parser`.
- `Client#upload` / `Fal.upload` — upload a local file (path or `IO`) to fal
  storage and get back its public URL, for image-to-image and image-to-video
  inputs. Content type is inferred from the file extension.
- Module-level conveniences `Fal.run`, `Fal.subscribe`, `Fal.stream`,
  `Fal.upload`, and `Fal.queue`, backed by a memoized `Fal.default_client`.
- `Queue#cancel(app_id, request_id)` — cancel a queued or in-progress request.
  Returns `true` once cancellation is requested, `false` when the request can no
  longer be cancelled (already finishing); other API errors raise.
- `webhook_url:` on `Client#subscribe` and `Queue#submit` to deliver results to
  your endpoint asynchronously (attached as the `fal_webhook` query parameter).
- `logs:` on `Client#subscribe` and `Queue#status` to include runner logs.
- `EndpointId`, a value object that parses ids like `fal-ai/flux/schnell` into
  the run path and the queue application path.
- `Configuration#rest_url` for the storage REST host.
- GitHub project scaffolding: issue and pull request templates, Dependabot
  config, `CODEOWNERS`, and a trusted-publishing release workflow.
- A `CLAUDE.md` guide and a rewritten README covering every feature.

### Changed

- **Breaking:** `Queue#status` and `Queue#result` now take `(app_id, request_id)`
  instead of a raw URL — matching the official fal clients and the documented
  README usage. The per-request URLs are constructed from the app root, so nested
  ids such as `fal-ai/flux/schnell` resolve correctly.
- **Breaking:** `SubmitResponse` now also exposes `app_id` and `cancel_url`.
- **Breaking:** removed the internal `Endpoints::Url`; queue endpoints are built
  from `(app_id, request_id)`.
- CI now tests against Ruby 3.3, 3.4, and 4.0 and runs on every pull request.
- `required_ruby_version` is now `>= 3.3`.
- `Gemfile.lock` is no longer committed (standard practice for libraries, so CI
  resolves against current dependency versions).

### Fixed

- `require "fal-ai"` now works. Previously the gem only defined `lib/fal.rb`, so
  `require "fal-ai"` (what the README documents and what Bundler auto-requires for
  `gem "fal-ai"`) raised `LoadError`.

### Changed

- **Breaking:** `Queue#status` and `Queue#result` now take `(app_id, request_id)`
  instead of a raw URL — matching the official fal clients and the documented
  README usage. The per-request URLs are constructed from the app root, so nested
  ids such as `fal-ai/flux/schnell` resolve correctly.
- **Breaking:** `SubmitResponse` now also exposes `app_id` and `cancel_url`.
- **Breaking:** removed the internal `Endpoints::Url`; queue endpoints are built
  from `(app_id, request_id)`.
- CI now tests against Ruby 3.3, 3.4, and 4.0 and runs on every pull request.
- `required_ruby_version` is now `>= 3.3`.
- `Gemfile.lock` is no longer committed (standard practice for libraries, so CI
  resolves against current dependency versions).

### Fixed

- `require "fal-ai"` now works. Previously the gem only defined `lib/fal.rb`, so
  `require "fal-ai"` (what the README documents and what Bundler auto-requires for
  `gem "fal-ai"`) raised `LoadError`.

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
