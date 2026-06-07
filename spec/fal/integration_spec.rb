# frozen_string_literal: true

require "webmock/rspec"

RSpec.describe "Integration: real HTTP via WebMock" do
  let(:config) do
    Fal::Configuration.new.tap do |c|
      c.api_key = "test-api-key"
      c.timeout = 5
      c.poll_interval = 0.01
    end
  end

  # Real HTTP client through Connection (no mocks) - WebMock intercepts.
  let(:client) { Fal::Client.new(config: config) }

  def queue
    "https://queue.fal.run"
  end

  # The queue endpoint returns status/response/cancel URLs rooted at the app
  # (e.g. "fal-ai/flux"), not the full variant path ("fal-ai/flux/schnell").
  def submit_body(request_id:, app:)
    JSON.generate(
      "request_id" => request_id,
      "status_url" => "#{queue}/#{app}/requests/#{request_id}/status",
      "response_url" => "#{queue}/#{app}/requests/#{request_id}",
      "cancel_url" => "#{queue}/#{app}/requests/#{request_id}/cancel",
      "status" => "IN_QUEUE"
    )
  end

  def ok(body)
    { status: 200, body: body, headers: { "Content-Type" => "application/json" } }
  end

  describe "nested model ids resolve to the app-rooted request path" do
    # The queue is per-app: a nested id like fal-ai/flux/schnell submits under the
    # full path but is polled under fal-ai/flux. EndpointId encapsulates that, and
    # these end-to-end stubs prove the URLs the gem constructs match the server's:
    #
    # Submit:  POST https://queue.fal.run/fal-ai/flux/schnell
    # Status:  GET  https://queue.fal.run/fal-ai/flux/requests/{id}/status
    # Result:  GET  https://queue.fal.run/fal-ai/flux/requests/{id}

    it "polls a nested model id under its app" do
      stub_request(:post, "#{queue}/fal-ai/flux/schnell")
        .to_return(ok(submit_body(request_id: "req-789", app: "fal-ai/flux")))
      stub_request(:get, "#{queue}/fal-ai/flux/requests/req-789/status")
        .to_return(ok('{"status": "COMPLETED"}'))
      stub_request(:get, "#{queue}/fal-ai/flux/requests/req-789")
        .to_return(ok('{"images": [{"url": "https://fal.media/test.png"}]}'))

      result = client.subscribe("fal-ai/flux/schnell", { prompt: "a cat" })

      expect(result).to eq({ "images" => [{ "url" => "https://fal.media/test.png" }] })
    end

    it "polls a deeply nested model id under its app" do
      app_id = "fal-ai/kling-video/v1.5/pro/image-to-video"
      stub_request(:post, "#{queue}/#{app_id}")
        .to_return(ok(submit_body(request_id: "req-deep", app: "fal-ai/kling-video")))
      stub_request(:get, "#{queue}/fal-ai/kling-video/requests/req-deep/status")
        .to_return(ok('{"status": "COMPLETED"}'))
      stub_request(:get, "#{queue}/fal-ai/kling-video/requests/req-deep")
        .to_return(ok('{"video": {"url": "https://fal.media/video.mp4"}}'))

      result = client.subscribe(app_id, { image_url: "https://example.com/img.png" })

      expect(result).to eq({ "video" => { "url" => "https://fal.media/video.mp4" } })
    end
  end

  describe "queue.submit" do
    it "returns a SubmitResponse with URLs from the API" do
      stub_request(:post, "#{queue}/fal-ai/flux/schnell")
        .to_return(ok(submit_body(request_id: "req-456", app: "fal-ai/flux")))

      submit_response = client.queue.submit("fal-ai/flux/schnell", { prompt: "a cat" })

      expect(submit_response).to be_a(Fal::SubmitResponse)
      expect(submit_response.request_id).to eq("req-456")
      expect(submit_response.status_url).to eq("#{queue}/fal-ai/flux/requests/req-456/status")
      expect(submit_response.cancel_url).to eq("#{queue}/fal-ai/flux/requests/req-456/cancel")
    end

    it "attaches a webhook URL as a query parameter" do
      hook = "https://example.com/fal-hook"
      stubbed = stub_request(:post, "#{queue}/fal-ai/flux/schnell")
                .with(query: { "fal_webhook" => hook })
                .to_return(ok(submit_body(request_id: "req-1", app: "fal-ai/flux")))

      client.queue.submit("fal-ai/flux/schnell", { prompt: "a cat" }, webhook_url: hook)

      expect(stubbed).to have_been_requested
    end
  end

  describe "queue.status" do
    it "fetches the status for an app id and request id" do
      stub_request(:get, "#{queue}/fal-ai/flux/requests/req-123/status")
        .to_return(ok('{"status": "IN_QUEUE", "queue_position": 3}'))

      status = client.queue.status("fal-ai/flux/schnell", "req-123")

      expect(status).to be_a(Fal::Status::Queued)
      expect(status.position).to eq(3)
    end
  end

  describe "queue.result" do
    it "fetches the result for an app id and request id" do
      stub_request(:get, "#{queue}/fal-ai/flux/requests/req-123")
        .to_return(ok('{"images": [{"url": "https://example.com/image.png"}]}'))

      result = client.queue.result("fal-ai/flux/schnell", "req-123")

      expect(result).to eq({ "images" => [{ "url" => "https://example.com/image.png" }] })
    end
  end

  describe "queue.cancel" do
    it "returns true when cancellation is accepted (202)" do
      stub_request(:put, "#{queue}/fal-ai/flux/requests/req-123/cancel")
        .to_return(status: 202, body: '{"status": "CANCELLATION_REQUESTED"}')

      expect(client.queue.cancel("fal-ai/flux/schnell", "req-123")).to be(true)
    end

    it "returns false when the request is already finished (400)" do
      stub_request(:put, "#{queue}/fal-ai/flux/requests/req-123/cancel")
        .to_return(status: 400, body: '{"status": "ALREADY_COMPLETED"}')

      expect(client.queue.cancel("fal-ai/flux/schnell", "req-123")).to be(false)
    end
  end

  describe "error handling" do
    def stub_status(status:, body:)
      stub_request(:get, "#{queue}/fal-ai/flux/requests/req-123/status")
        .to_return(status: status, body: body)
    end

    it "raises AuthenticationError on 401" do
      stub_status(status: 401, body: '{"detail": "Invalid API key"}')

      expect { client.queue.status("fal-ai/flux/schnell", "req-123") }
        .to raise_error(Fal::AuthenticationError, "Invalid API key")
    end

    it "raises RateLimitError on 429" do
      stub_status(status: 429, body: '{"detail": "Rate limited"}')

      expect { client.queue.status("fal-ai/flux/schnell", "req-123") }
        .to raise_error(Fal::RateLimitError, "Rate limited")
    end

    it "raises ConnectionError on network timeout" do
      stub_request(:get, "#{queue}/fal-ai/flux/requests/req-123/status").to_timeout

      expect { client.queue.status("fal-ai/flux/schnell", "req-123") }
        .to raise_error(Fal::ConnectionError, /HTTP request failed/)
    end
  end
end
