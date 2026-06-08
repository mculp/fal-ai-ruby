# fal-ai

[![Gem Version](https://badge.fury.io/rb/fal-ai.svg)](https://rubygems.org/gems/fal-ai)
[![CI](https://github.com/mculp/fal-ai-ruby/actions/workflows/ci.yml/badge.svg)](https://github.com/mculp/fal-ai-ruby/actions/workflows/ci.yml)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.3-CC342D.svg)](https://www.ruby-lang.org)

A Ruby client for [fal.ai](https://fal.ai) — run inference on 600+ generative models
(Flux, Stable Diffusion, Kling, Veo, Nano Banana, and more) to generate images,
video, audio, and text from your Ruby app.

It mirrors the ergonomics of the official [JavaScript](https://github.com/fal-ai/fal-js)
and [Python](https://github.com/fal-ai/fal-client) clients, with a small, idiomatic,
object-oriented design that should feel at home to Ruby developers.

## Features

- **`run`** — synchronous inference for quick models.
- **`subscribe`** — submit to the queue and poll to completion, with status callbacks and runner logs.
- **`stream`** — consume Server-Sent Events for models that stream partial results.
- **`queue`** — low-level `submit` / `status` / `result` / `cancel` for full control.
- **`upload`** — push local files to fal storage and get back URLs for image-to-image and image-to-video.
- **Webhooks** — deliver results to your own endpoint asynchronously.
- **Typed errors** and **polymorphic status objects** — no string-matching on responses.
- **Dependency-injected** HTTP layer (built on [Faraday](https://github.com/lostisland/faraday), pure Ruby — no native extensions) — trivial to test.

## Installation

Add it to your Gemfile:

```ruby
gem "fal-ai"
```

```bash
bundle install
```

Or install it directly:

```bash
gem install fal-ai
```

Then require it:

```ruby
require "fal-ai"
```

## Configuration

Set your API key via the `FAL_KEY` environment variable (recommended) or configure it explicitly:

```ruby
require "fal-ai"

Fal.configure do |config|
  config.api_key      = "your-api-key"  # defaults to ENV["FAL_KEY"]
  config.timeout      = 300             # seconds (default: 300)
  config.poll_interval = 0.5            # seconds between queue polls (default: 0.5)
end
```

Get a key from the [fal dashboard](https://fal.ai/dashboard/keys).

## Generating an image

### Synchronous run

For fast models, `run` blocks until the result is ready:

```ruby
result = Fal.run("fal-ai/flux/schnell", {
  prompt: "a red panda reading a book in a cozy library, warm light",
  image_size: "landscape_16_9"
})

puts result["images"].first["url"]
```

`Fal.run` (and `subscribe`, `stream`, `upload`, `queue`) are module-level conveniences
that use a default client over your global configuration. For multiple configurations,
build a client explicitly with `Fal.client`.

### Subscribe (queue + polling)

For longer-running models, `subscribe` enqueues the request and polls until it's done,
yielding status updates along the way:

```ruby
result = Fal.subscribe("fal-ai/flux/dev", { prompt: "an astronaut on a horse" }, logs: true) do |status|
  case status
  when Fal::Status::Queued     then puts "Queued at position #{status.position}"
  when Fal::Status::InProgress then puts status.logs.map { |l| l["message"] }
  end
end

puts result["images"].first["url"]
```

## Generating a video

Video models are queue-based. Image-to-video models take an input image URL —
use `upload` to turn a local file into one:

```ruby
client = Fal.client

image_url = client.upload("./first_frame.png")

video = client.subscribe("fal-ai/kling-video/v1.5/pro/image-to-video", {
  prompt: "the camera slowly pushes in",
  image_url: image_url
})

puts video["video"]["url"]
```

## Streaming

For models that stream partial results, `stream` yields each event as it arrives and
returns the final one (the completed result):

```ruby
final = Fal.stream("fal-ai/any-llm", { prompt: "Write a haiku about Ruby." }) do |event|
  print event["output"] if event["output"]
end

puts "\n\nFinal: #{final}"
```

## Uploading files

`upload` accepts a path or any `IO`, infers the content type from the extension, and
returns the public URL:

```ruby
client = Fal.client

client.upload("./portrait.jpg")                          # => "https://v3.fal.media/files/.../portrait.jpg"
client.upload(StringIO.new(bytes), content_type: "image/png", file_name: "frame.png")
```

## Direct queue operations

`submit` returns a `SubmitResponse`; `status`, `result`, and `cancel` are addressed by
`(app_id, request_id)` — the same shape as the official clients:

```ruby
client = Fal.client

submission = client.queue.submit("fal-ai/flux/dev", { prompt: "a dog playing fetch" })
puts submission.request_id

loop do
  status = client.queue.status("fal-ai/flux/dev", submission.request_id, logs: true)
  break if status.completed?

  sleep 1
end

result = client.queue.result("fal-ai/flux/dev", submission.request_id)
puts result["images"].first["url"]
```

### Cancelling

```ruby
# Returns true once cancellation is requested, false if the request is already finishing.
client.queue.cancel("fal-ai/flux/dev", submission.request_id)
```

## Webhooks

Pass a `webhook_url` to deliver the result to your endpoint instead of polling. fal POSTs
the completed request to that URL:

```ruby
client.queue.submit("fal-ai/flux/dev", { prompt: "a cat" }, webhook_url: "https://your.app/fal/webhook")
```

> **Verify the signature on your receiver.** fal POSTs results to your endpoint with no
> credentials of yours attached, so the request is unauthenticated from your app's
> perspective — anyone who learns the URL could forge a delivery. fal signs each webhook
> with an ED25519 signature in the `X-Fal-Webhook-Signature` header, verifiable against
> fal's JWKS at <https://rest.fal.ai/.well-known/jwks.json>. Until this gem ships a
> built-in verifier (see the [Roadmap](#roadmap)), your receiver MUST verify that signature
> itself before trusting the payload.

## Status objects

Polling yields polymorphic status objects rather than raw strings, so you ask them what
they are:

| Class | Predicate | Useful methods |
|-------|-----------|----------------|
| `Fal::Status::Queued` | `queued?` | `position` |
| `Fal::Status::InProgress` | `in_progress?` | `logs` |
| `Fal::Status::Completed` | `completed?` | `logs`, `metrics` |

## Error handling

Every non-2xx response raises a typed error so you can rescue precisely:

```ruby
begin
  Fal.run("fal-ai/flux/dev", { prompt: "a cat" })
rescue Fal::AuthenticationError       # 401
  warn "Check your API key"
rescue Fal::RateLimitError => e        # 429
  warn "Rate limited (#{e.status_code})"
rescue Fal::NotFoundError              # 404
  warn "No such model"
rescue Fal::ServerError                # 5xx
  warn "fal had a problem"
rescue Fal::ApiError => e              # any other non-2xx
  warn "API error #{e.status_code}: #{e.message}"
rescue Fal::ConnectionError => e       # network failure
  warn "Network issue: #{e.original_error}"
rescue Fal::TimeoutError               # subscribe polling exceeded config.timeout
  warn "Timed out"
end
```

All errors descend from `Fal::Error`, so `rescue Fal::Error` catches everything.

## Architecture

The gem is a thin facade over small, single-responsibility collaborators — each easy to
read, test, and replace:

| Object | Responsibility |
|--------|----------------|
| `Fal::Client` | Public facade: `run`, `subscribe`, `stream`, `upload`, `queue` |
| `Fal::Configuration` | API key, timeout, poll interval, base URLs |
| `Fal::Connection` | HTTP transport (Faraday), status → typed errors |
| `Fal::Endpoints::*` | URL + method value objects for each fal endpoint |
| `Fal::EndpointId` | Thin value object wrapping an endpoint id (coerce + equality) |
| `Fal::Queue` | `submit` / `status` / `result` / `cancel` |
| `Fal::Subscriber` | Polls the queue to completion |
| `Fal::Streaming` + `Fal::Sse::Parser` | Server-Sent Events consumption |
| `Fal::Storage` | Two-step presigned file upload |
| `Fal::Status::*` | Polymorphic queue status |

Collaborators are injected, so in tests you can swap the HTTP layer without touching the rest.

## Development

```bash
bin/setup                 # install dependencies
bundle exec rake          # run RSpec + RuboCop (the default task)
bundle exec rspec         # tests only
bin/console               # an IRB session with the gem loaded
```

This project is test-driven; please add a failing test before a fix or feature.

## Roadmap

Out of scope for now, but on the radar:

- Realtime (WebSocket) endpoints
- Webhook signature verification helper
- Automatic upload of file objects passed directly in model input
- Proxy / custom-gateway routing
- Multipart upload for large files — the current `upload` is a single PUT; the official clients chunk files above ~90 MB
- Per-call `timeout` and `poll_interval` overrides on `subscribe` (currently only global via `Fal.configure`)
- Queue status streaming (`queue.stream_status` / `subscribe(mode: :streaming)`) over SSE, as a lower-latency alternative to polling

## Contributing

Bug reports and pull requests are welcome on GitHub at
<https://github.com/mculp/fal-ai-ruby>. Run `bundle exec rake` before opening a PR.

## License

Available as open source under the terms of the [MIT License](LICENSE.txt).
