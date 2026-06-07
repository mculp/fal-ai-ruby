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

  # The queue endpoint returns status/response URLs rooted at the app (e.g.
  # "fal-ai/flux"), not the full variant path ("fal-ai/flux/schnell").
  def submit_body(request_id:, app:)
    JSON.generate(
      "request_id" => request_id,
      "status_url" => "#{queue}/#{app}/requests/#{request_id}/status",
      "response_url" => "#{queue}/#{app}/requests/#{request_id}",
      "status" => "IN_QUEUE"
    )
  end

  def ok(body)
    { status: 200, body: body, headers: { "Content-Type" => "application/json" } }
  end

  describe "nested model IDs (the bug)" do
    # The FAL API returns status/result URLs that differ from the submit URL for
    # nested models. The submit URL uses the full model path, but the returned
    # URLs strip the variant suffix:
    #
    # Submit:  POST https://queue.fal.run/fal-ai/flux/schnell
    # Status:  GET  https://queue.fal.run/fal-ai/flux/requests/{id}/status  (NOT /flux/schnell/...)
    # Result:  GET  https://queue.fal.run/fal-ai/flux/requests/{id}         (NOT /flux/schnell/...)

    it "uses API-returned URLs for status and result, not constructed ones" do
      stub_request(:post, "#{queue}/fal-ai/flux/schnell")
        .to_return(ok(submit_body(request_id: "req-789", app: "fal-ai/flux")))
      stub_request(:get, "#{queue}/fal-ai/flux/requests/req-789/status")
        .to_return(ok('{"status": "COMPLETED"}'))
      stub_request(:get, "#{queue}/fal-ai/flux/requests/req-789")
        .to_return(ok('{"images": [{"url": "https://fal.media/test.png"}]}'))

      result = client.subscribe("fal-ai/flux/schnell", { prompt: "a cat" })

      expect(result).to eq({ "images" => [{ "url" => "https://fal.media/test.png" }] })
    end

    it "works with deeply nested model IDs" do
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
      expect(submit_response.response_url).to eq("#{queue}/fal-ai/flux/requests/req-456")
    end
  end

  describe "queue.status" do
    it "fetches status from the given URL" do
      stub_request(:get, "#{queue}/fal-ai/flux/requests/req-123/status")
        .to_return(ok('{"status": "IN_QUEUE", "queue_position": 3}'))

      status = client.queue.status("#{queue}/fal-ai/flux/requests/req-123/status")

      expect(status).to be_a(Fal::Status::Queued)
      expect(status.position).to eq(3)
    end
  end

  describe "queue.result" do
    it "fetches result from the given URL" do
      stub_request(:get, "#{queue}/fal-ai/flux/requests/req-123")
        .to_return(ok('{"images": [{"url": "https://example.com/image.png"}]}'))

      result = client.queue.result("#{queue}/fal-ai/flux/requests/req-123")

      expect(result).to eq({ "images" => [{ "url" => "https://example.com/image.png" }] })
    end
  end

  describe "subscribe with polling" do
    it "yields status updates while polling" do
      stub_request(:post, "#{queue}/fal-ai/flux/schnell")
        .to_return(ok(submit_body(request_id: "req-789", app: "fal-ai/flux")))
      stub_request(:get, "#{queue}/fal-ai/flux/requests/req-789/status")
        .to_return(
          ok('{"status": "IN_QUEUE", "queue_position": 2}'),
          ok('{"status": "IN_PROGRESS"}'),
          ok('{"status": "COMPLETED"}')
        )
      stub_request(:get, "#{queue}/fal-ai/flux/requests/req-789")
        .to_return(ok('{"images": []}'))

      statuses = []
      client.subscribe("fal-ai/flux/schnell", { prompt: "a cat" }) { |s| statuses << s }

      expected = [Fal::Status::Queued, Fal::Status::InProgress, Fal::Status::Completed]
      expect(statuses.map(&:class)).to eq(expected)
    end
  end

  describe "error handling" do
    let(:status_url) { "#{queue}/fal-ai/flux/requests/req-123/status" }

    it "raises AuthenticationError on 401" do
      stub_request(:get, status_url).to_return(status: 401, body: '{"detail": "Invalid API key"}')

      expect { client.queue.status(status_url) }
        .to raise_error(Fal::AuthenticationError, "Invalid API key")
    end

    it "raises RateLimitError on 429" do
      stub_request(:get, status_url).to_return(status: 429, body: '{"detail": "Rate limited"}')

      expect { client.queue.status(status_url) }
        .to raise_error(Fal::RateLimitError, "Rate limited")
    end

    it "raises ConnectionError on network timeout" do
      stub_request(:get, status_url).to_timeout

      expect { client.queue.status(status_url) }
        .to raise_error(Fal::ConnectionError, /HTTP request failed/)
    end
  end
end
