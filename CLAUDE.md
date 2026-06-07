# CLAUDE.md

Guidance for Claude when **using** the `fal-ai` gem in a Ruby project, or **working on**
the gem itself.

## What this gem is

A Ruby client for the [fal.ai](https://fal.ai) Model API. It runs inference on hosted
generative models (image, video, audio, text) over HTTP. It is a thin, object-oriented
facade — no global mutable state beyond an explicit `Fal.configure` block.

## Mental model

A `Fal::Client` is a facade that delegates to focused collaborators. You almost never
touch the collaborators directly; you call the client (or the module-level shortcuts).

```
Fal.run/subscribe/stream/upload/queue  ->  Fal.default_client (a Fal::Client)
Fal::Client ──> Queue ──> Connection ──> Faraday
            ──> Subscriber ──> Queue
            ──> Streaming ──> Sse::Parser
            ──> Storage ──> Connection
```

Two hosts matter:
- `https://fal.run/{id}` — synchronous `run`, and `…/stream` for streaming.
- `https://queue.fal.run/{id}` — queue submit; per-request URLs are
  `…/{id}/requests/{request_id}[/status|/cancel]` using the **full** id (the variant is
  kept). Build them with `Fal::Endpoints::*`, never by hand.

## Choosing a method

| Want | Use |
|------|-----|
| A fast model, block for the result | `Fal.run(id, input)` |
| A slow model, poll with progress | `Fal.subscribe(id, input) { \|status\| … }` |
| Partial results as they generate | `Fal.stream(id, input) { \|event\| … }` |
| Fire-and-forget, get a webhook | `client.queue.submit(id, input, webhook_url:)` |
| Manual control over the queue | `client.queue.submit/status/result/cancel` |
| A local file as model input | `client.upload(path_or_io)` → URL |

`run` can time out at the gateway for long models — prefer `subscribe` for video and other
slow generations.

## Setup (one time)

```ruby
require "fal-ai"
Fal.configure { |c| c.api_key = ENV.fetch("FAL_KEY") } # or just set ENV["FAL_KEY"]
```

## Recipes

**Generate an image:**
```ruby
result = Fal.run("fal-ai/flux/schnell", { prompt: "a cat", image_size: "square_hd" })
result["images"].first["url"]
```

**Generate a video from a local image (upload + subscribe):**
```ruby
client = Fal.client
image_url = client.upload("./frame.png")
video = client.subscribe("fal-ai/kling-video/v1.5/pro/image-to-video",
                         { prompt: "push in slowly", image_url: image_url })
video["video"]["url"]
```

**Stream tokens/partials:**
```ruby
final = Fal.stream("fal-ai/any-llm", { prompt: "Haiku about Ruby" }) do |event|
  print event["output"]
end
```

**Queue by hand (store the id, poll later, maybe cancel):**
```ruby
submission = client.queue.submit("fal-ai/flux/dev", { prompt: "a dog" })
status = client.queue.status("fal-ai/flux/dev", submission.request_id)
result = client.queue.result("fal-ai/flux/dev", submission.request_id) if status.completed?
client.queue.cancel("fal-ai/flux/dev", submission.request_id)
```

## Key facts and gotchas

- **`run` returns a `Hash`** with string keys (the raw model output). Output shape is
  model-specific: image models return `result["images"]`, video models `result["video"]`.
- **`submit` returns a `Fal::SubmitResponse`** (`request_id`, `status_url`, `response_url`,
  `cancel_url`, `app_id`), not a bare id. Use `submission.request_id`.
- **Webhooks are delivery-only — verification is the receiver's job.** Passing `webhook_url`
  makes fal POST the result to your endpoint, but the gem does not verify fal's signature
  (yet). Your receiver MUST validate the ED25519 `X-Fal-Webhook-Signature` header against
  fal's JWKS (<https://rest.fal.ai/.well-known/jwks.json>) before trusting the payload.
- **`status`/`result`/`cancel` take `(app_id, request_id)`**, not a URL. Pass the same
  `app_id` you submitted with — nested ids like `fal-ai/flux/schnell` are handled correctly.
- **`cancel` returns a boolean**: `true` if cancellation was requested, `false` if the
  request was already finishing (HTTP 400). Other failures raise.
- **`stream` returns the final event**; the block sees every event. Without a block it still
  returns the final event.
- **Status objects are polymorphic** — branch with `case status when Fal::Status::Queued`
  or ask `status.completed?`; don't compare strings.
- **Errors are typed** and all descend from `Fal::Error`: `AuthenticationError` (401),
  `NotFoundError` (404), `RateLimitError` (429), `ServerError` (5xx), `ApiError` (other
  non-2xx, carries `#status_code`), `ConnectionError` (network, carries `#original_error`),
  `TimeoutError` (subscribe polling exceeded `config.timeout`).
- **Find model ids and input schemas** on the model's page at <https://fal.ai/models>.
  This gem does not validate input — it passes your hash straight through.

## Working on the gem

- **TDD is required.** Write a failing spec, watch it fail, then implement. Each object has
  a spec under `spec/fal/`.
- **Run checks:** `bundle exec rake` (RSpec + RuboCop). Tests use WebMock; no live calls.
- **HTTP goes through `Fal::Connection`** (Faraday) — never use `Net::HTTP` directly, and
  never hand-build fal URLs (use `Fal::Endpoints::*` + `Fal::EndpointId`).
- **Keep methods small and inject collaborators** (RuboCop enforces `Metrics/MethodLength`).
  New behavior is usually a new small object plus a require in `lib/fal.rb`.
- **Supported Rubies:** 3.3, 3.4, 4.0 (CI matrix). Don't use APIs newer than 3.3.
- **Deferred (parity gaps, not yet built):** webhook signature verification, realtime
  WebSocket, multipart upload for large files, per-call `subscribe` timeout/poll overrides,
  and queue status streaming over SSE. See the README Roadmap.

### File map

| Path | What |
|------|------|
| `lib/fal.rb` | Requires + the `Fal` module (config, default client, shortcuts) |
| `lib/fal-ai.rb` | Gem-name entrypoint (`require "fal-ai"`) → loads `fal` |
| `lib/fal/client.rb` | The facade |
| `lib/fal/configuration.rb` | Settings + base URLs |
| `lib/fal/connection.rb` | Faraday transport, status → typed errors |
| `lib/fal/endpoint_id.rb` | Thin endpoint-id value object (coerce + equality) |
| `lib/fal/endpoints.rb` | Per-endpoint URL/method value objects |
| `lib/fal/queue.rb` | submit/status/result/cancel + `SubmitResponse` |
| `lib/fal/subscriber.rb` | Queue polling loop |
| `lib/fal/streaming.rb`, `lib/fal/sse/parser.rb` | SSE streaming |
| `lib/fal/storage.rb` | Presigned file upload |
| `lib/fal/response.rb`, `lib/fal/status.rb`, `lib/fal/errors.rb` | Response parsing, status, errors |
