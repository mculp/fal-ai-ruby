# frozen_string_literal: true

require "webmock/rspec"
require "stringio"

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

  # The queue addresses every per-request URL by the FULL endpoint id, including
  # the variant (e.g. "fal-ai/flux/schnell"), matching the official fal clients.
  def submit_body(request_id:, id:)
    JSON.generate(
      "request_id" => request_id,
      "status_url" => "#{queue}/#{id}/requests/#{request_id}/status",
      "response_url" => "#{queue}/#{id}/requests/#{request_id}",
      "cancel_url" => "#{queue}/#{id}/requests/#{request_id}/cancel",
      "status" => "IN_QUEUE"
    )
  end

  def ok(body)
    { status: 200, body: body, headers: { "Content-Type" => "application/json" } }
  end

  describe "nested model ids keep the full id in request URLs" do
    # A nested id like fal-ai/flux/schnell submits AND polls under the full path.
    # These end-to-end stubs prove the URLs the gem constructs match the server's:
    #
    # Submit:  POST https://queue.fal.run/fal-ai/flux/schnell
    # Status:  GET  https://queue.fal.run/fal-ai/flux/schnell/requests/{id}/status
    # Result:  GET  https://queue.fal.run/fal-ai/flux/schnell/requests/{id}

    it "polls a nested model id under its full id" do
      stub_request(:post, "#{queue}/fal-ai/flux/schnell")
        .to_return(ok(submit_body(request_id: "req-789", id: "fal-ai/flux/schnell")))
      stub_request(:get, "#{queue}/fal-ai/flux/schnell/requests/req-789/status")
        .to_return(ok('{"status": "COMPLETED"}'))
      stub_request(:get, "#{queue}/fal-ai/flux/schnell/requests/req-789")
        .to_return(ok('{"images": [{"url": "https://fal.media/test.png"}]}'))

      result = client.subscribe("fal-ai/flux/schnell", { prompt: "a cat" })

      expect(result).to eq({ "images" => [{ "url" => "https://fal.media/test.png" }] })
    end

    it "polls a deeply nested model id under its full id" do
      app_id = "fal-ai/kling-video/v1.5/pro/image-to-video"
      stub_request(:post, "#{queue}/#{app_id}")
        .to_return(ok(submit_body(request_id: "req-deep", id: app_id)))
      stub_request(:get, "#{queue}/#{app_id}/requests/req-deep/status")
        .to_return(ok('{"status": "COMPLETED"}'))
      stub_request(:get, "#{queue}/#{app_id}/requests/req-deep")
        .to_return(ok('{"video": {"url": "https://fal.media/video.mp4"}}'))

      result = client.subscribe(app_id, { image_url: "https://example.com/img.png" })

      expect(result).to eq({ "video" => { "url" => "https://fal.media/video.mp4" } })
    end
  end

  describe "queue.submit" do
    it "returns a SubmitResponse with URLs from the API" do
      stub_request(:post, "#{queue}/fal-ai/flux/schnell")
        .to_return(ok(submit_body(request_id: "req-456", id: "fal-ai/flux/schnell")))

      submit_response = client.queue.submit("fal-ai/flux/schnell", { prompt: "a cat" })

      expect(submit_response).to be_a(Fal::SubmitResponse)
      expect(submit_response.request_id).to eq("req-456")
      expect(submit_response.status_url).to eq("#{queue}/fal-ai/flux/schnell/requests/req-456/status")
      expect(submit_response.cancel_url).to eq("#{queue}/fal-ai/flux/schnell/requests/req-456/cancel")
    end

    it "attaches a webhook URL as a query parameter" do
      hook = "https://example.com/fal-hook"
      stubbed = stub_request(:post, "#{queue}/fal-ai/flux/schnell")
                .with(query: { "fal_webhook" => hook })
                .to_return(ok(submit_body(request_id: "req-1", id: "fal-ai/flux/schnell")))

      client.queue.submit("fal-ai/flux/schnell", { prompt: "a cat" }, webhook_url: hook)

      expect(stubbed).to have_been_requested
    end
  end

  describe "queue.status" do
    it "fetches the status for an app id and request id" do
      stub_request(:get, "#{queue}/fal-ai/flux/schnell/requests/req-123/status")
        .to_return(ok('{"status": "IN_QUEUE", "queue_position": 3}'))

      status = client.queue.status("fal-ai/flux/schnell", "req-123")

      expect(status).to be_a(Fal::Status::Queued)
      expect(status.position).to eq(3)
    end
  end

  describe "queue.result" do
    it "fetches the result for an app id and request id" do
      stub_request(:get, "#{queue}/fal-ai/flux/schnell/requests/req-123")
        .to_return(ok('{"images": [{"url": "https://example.com/image.png"}]}'))

      result = client.queue.result("fal-ai/flux/schnell", "req-123")

      expect(result).to eq({ "images" => [{ "url" => "https://example.com/image.png" }] })
    end
  end

  describe "subscribe polling progression" do
    it "yields each status in order while polling to completion" do
      stub_request(:post, "#{queue}/fal-ai/flux/schnell")
        .to_return(ok(submit_body(request_id: "req-poll", id: "fal-ai/flux/schnell")))
      stub_request(:get, "#{queue}/fal-ai/flux/schnell/requests/req-poll/status")
        .to_return(
          ok('{"status": "IN_QUEUE", "queue_position": 2}'),
          ok('{"status": "IN_PROGRESS"}'),
          ok('{"status": "COMPLETED"}')
        )
      stub_request(:get, "#{queue}/fal-ai/flux/schnell/requests/req-poll")
        .to_return(ok('{"images": []}'))

      statuses = []
      client.subscribe("fal-ai/flux/schnell", { prompt: "a cat" }) { |s| statuses << s }

      expect(statuses.map(&:class))
        .to eq([Fal::Status::Queued, Fal::Status::InProgress, Fal::Status::Completed])
    end
  end

  describe "stream" do
    it "consumes Server-Sent Events end to end" do
      sse = "data: {\"progress\": 0.5}\n\n" \
            "data: {\"images\": [{\"url\": \"https://fal.media/x.png\"}]}\n\n"
      stub_request(:post, "https://fal.run/fal-ai/flux/dev/stream")
        .with(headers: { "Accept" => "text/event-stream" })
        .to_return(status: 200, body: sse, headers: { "Content-Type" => "text/event-stream" })

      events = []
      result = client.stream("fal-ai/flux/dev", { prompt: "a cat" }) { |event| events << event }

      expect(events.first).to eq({ "progress" => 0.5 })
      expect(result).to eq({ "images" => [{ "url" => "https://fal.media/x.png" }] })
    end
  end

  describe "queue.cancel" do
    it "returns true when cancellation is accepted (202)" do
      stub_request(:put, "#{queue}/fal-ai/flux/schnell/requests/req-123/cancel")
        .to_return(status: 202, body: '{"status": "CANCELLATION_REQUESTED"}')

      expect(client.queue.cancel("fal-ai/flux/schnell", "req-123")).to be(true)
    end

    it "returns false when the request is already finished (400)" do
      stub_request(:put, "#{queue}/fal-ai/flux/schnell/requests/req-123/cancel")
        .to_return(status: 400, body: '{"status": "ALREADY_COMPLETED"}')

      expect(client.queue.cancel("fal-ai/flux/schnell", "req-123")).to be(false)
    end
  end

  describe "storage.upload" do
    it "initiates, PUTs the bytes, and returns the public URL" do
      initiate = stub_request(
        :post, "https://rest.fal.ai/storage/upload/initiate?storage_type=fal-cdn-v3"
      ).to_return(ok(JSON.generate(
                       "upload_url" => "https://upload.fal.example/put/xyz",
                       "file_url" => "https://v3.fal.media/files/xyz/a.png"
                     )))
      put = stub_request(:put, "https://upload.fal.example/put/xyz")
            .with(body: "PNGBYTES", headers: { "Content-Type" => "image/png" })
            .to_return(status: 200, body: "")

      url = client.upload(StringIO.new("PNGBYTES"), content_type: "image/png", file_name: "a.png")

      expect(url).to eq("https://v3.fal.media/files/xyz/a.png")
      expect(initiate).to have_been_requested
      expect(put).to have_been_requested
    end
  end

  describe "error handling" do
    def stub_status(status:, body:)
      stub_request(:get, "#{queue}/fal-ai/flux/schnell/requests/req-123/status")
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
      stub_request(:get, "#{queue}/fal-ai/flux/schnell/requests/req-123/status").to_timeout

      expect { client.queue.status("fal-ai/flux/schnell", "req-123") }
        .to raise_error(Fal::ConnectionError, /HTTP request failed/)
    end
  end
end
