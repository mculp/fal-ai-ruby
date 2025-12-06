# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
