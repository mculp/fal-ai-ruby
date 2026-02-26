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

  # Use real HTTP client through Connection (no mocks) - WebMock intercepts
  let(:client) { Fal::Client.new(config: config) }

  describe "nested model IDs (the bug)" do
    # The FAL API returns status/result URLs that differ from the submit URL
    # for nested models like fal-ai/flux/schnell. The submit URL uses the full
    # model path, but the returned URLs strip the variant suffix.
    #
    # Submit:  POST https://queue.fal.run/fal-ai/flux/schnell
    # Status:  GET  https://queue.fal.run/fal-ai/flux/requests/{id}/status  (NOT /flux/schnell/...)
    # Result:  GET  https://queue.fal.run/fal-ai/flux/requests/{id}         (NOT /flux/schnell/...)

    it "uses API-returned URLs for status and result, not constructed ones" do
      # Submit to nested model
      stub_request(:post, "https://queue.fal.run/fal-ai/flux/schnell")
        .to_return(
          status: 200,
          body: '{"request_id": "req-789", "status_url": "https://queue.fal.run/fal-ai/flux/requests/req-789/status", "response_url": "https://queue.fal.run/fal-ai/flux/requests/req-789", "status": "IN_QUEUE"}',
          headers: { "Content-Type" => "application/json" }
        )

      # Status URL uses fal-ai/flux (not fal-ai/flux/schnell)
      stub_request(:get, "https://queue.fal.run/fal-ai/flux/requests/req-789/status")
        .to_return(
          status: 200,
          body: '{"status": "COMPLETED"}',
          headers: { "Content-Type" => "application/json" }
        )

      # Result URL uses fal-ai/flux (not fal-ai/flux/schnell)
      stub_request(:get, "https://queue.fal.run/fal-ai/flux/requests/req-789")
        .to_return(
          status: 200,
          body: '{"images": [{"url": "https://fal.media/test.png"}]}',
          headers: { "Content-Type" => "application/json" }
        )

      result = client.subscribe("fal-ai/flux/schnell", { prompt: "a cat" })

      expect(result).to eq({ "images" => [{ "url" => "https://fal.media/test.png" }] })
    end

    it "works with deeply nested model IDs" do
      stub_request(:post, "https://queue.fal.run/fal-ai/kling-video/v1.5/pro/image-to-video")
        .to_return(
          status: 200,
          body: '{"request_id": "req-deep", "status_url": "https://queue.fal.run/fal-ai/kling-video/requests/req-deep/status", "response_url": "https://queue.fal.run/fal-ai/kling-video/requests/req-deep", "status": "IN_QUEUE"}',
          headers: { "Content-Type" => "application/json" }
        )

      stub_request(:get, "https://queue.fal.run/fal-ai/kling-video/requests/req-deep/status")
        .to_return(
          status: 200,
          body: '{"status": "COMPLETED"}',
          headers: { "Content-Type" => "application/json" }
        )

      stub_request(:get, "https://queue.fal.run/fal-ai/kling-video/requests/req-deep")
        .to_return(
          status: 200,
          body: '{"video": {"url": "https://fal.media/video.mp4"}}',
          headers: { "Content-Type" => "application/json" }
        )

      result = client.subscribe("fal-ai/kling-video/v1.5/pro/image-to-video", { image_url: "https://example.com/img.png" })

      expect(result).to eq({ "video" => { "url" => "https://fal.media/video.mp4" } })
    end
  end

  describe "queue.submit" do
    it "returns a SubmitResponse with URLs from the API" do
      stub_request(:post, "https://queue.fal.run/fal-ai/flux/schnell")
        .to_return(
          status: 200,
          body: '{"request_id": "req-456", "status_url": "https://queue.fal.run/fal-ai/flux/requests/req-456/status", "response_url": "https://queue.fal.run/fal-ai/flux/requests/req-456", "status": "IN_QUEUE"}',
          headers: { "Content-Type" => "application/json" }
        )

      submit_response = client.queue.submit("fal-ai/flux/schnell", { prompt: "a cat" })

      expect(submit_response).to be_a(Fal::SubmitResponse)
      expect(submit_response.request_id).to eq("req-456")
      expect(submit_response.status_url).to eq("https://queue.fal.run/fal-ai/flux/requests/req-456/status")
      expect(submit_response.response_url).to eq("https://queue.fal.run/fal-ai/flux/requests/req-456")
    end
  end

  describe "queue.status" do
    it "fetches status from the given URL" do
      stub_request(:get, "https://queue.fal.run/fal-ai/flux/requests/req-123/status")
        .to_return(
          status: 200,
          body: '{"status": "IN_QUEUE", "queue_position": 3}',
          headers: { "Content-Type" => "application/json" }
        )

      status = client.queue.status("https://queue.fal.run/fal-ai/flux/requests/req-123/status")

      expect(status).to be_a(Fal::Status::Queued)
      expect(status.position).to eq(3)
    end
  end

  describe "queue.result" do
    it "fetches result from the given URL" do
      stub_request(:get, "https://queue.fal.run/fal-ai/flux/requests/req-123")
        .to_return(
          status: 200,
          body: '{"images": [{"url": "https://example.com/image.png"}]}',
          headers: { "Content-Type" => "application/json" }
        )

      result = client.queue.result("https://queue.fal.run/fal-ai/flux/requests/req-123")

      expect(result).to eq({ "images" => [{ "url" => "https://example.com/image.png" }] })
    end
  end

  describe "subscribe with polling" do
    it "yields status updates while polling" do
      stub_request(:post, "https://queue.fal.run/fal-ai/flux/schnell")
        .to_return(
          status: 200,
          body: '{"request_id": "req-789", "status_url": "https://queue.fal.run/fal-ai/flux/requests/req-789/status", "response_url": "https://queue.fal.run/fal-ai/flux/requests/req-789", "status": "IN_QUEUE"}',
          headers: { "Content-Type" => "application/json" }
        )

      stub_request(:get, "https://queue.fal.run/fal-ai/flux/requests/req-789/status")
        .to_return(
          { status: 200, body: '{"status": "IN_QUEUE", "queue_position": 2}', headers: { "Content-Type" => "application/json" } },
          { status: 200, body: '{"status": "IN_PROGRESS"}', headers: { "Content-Type" => "application/json" } },
          { status: 200, body: '{"status": "COMPLETED"}', headers: { "Content-Type" => "application/json" } }
        )

      stub_request(:get, "https://queue.fal.run/fal-ai/flux/requests/req-789")
        .to_return(
          status: 200,
          body: '{"images": []}',
          headers: { "Content-Type" => "application/json" }
        )

      statuses = []
      client.subscribe("fal-ai/flux/schnell", { prompt: "a cat" }) { |s| statuses << s }

      expect(statuses.map(&:class)).to eq([
        Fal::Status::Queued,
        Fal::Status::InProgress,
        Fal::Status::Completed
      ])
    end
  end

  describe "error handling" do
    it "raises AuthenticationError on 401" do
      stub_request(:get, "https://queue.fal.run/fal-ai/flux/requests/req-123/status")
        .to_return(
          status: 401,
          body: '{"detail": "Invalid API key"}',
          headers: { "Content-Type" => "application/json" }
        )

      expect { client.queue.status("https://queue.fal.run/fal-ai/flux/requests/req-123/status") }
        .to raise_error(Fal::AuthenticationError, "Invalid API key")
    end

    it "raises RateLimitError on 429" do
      stub_request(:get, "https://queue.fal.run/fal-ai/flux/requests/req-123/status")
        .to_return(
          status: 429,
          body: '{"detail": "Rate limited"}',
          headers: { "Content-Type" => "application/json" }
        )

      expect { client.queue.status("https://queue.fal.run/fal-ai/flux/requests/req-123/status") }
        .to raise_error(Fal::RateLimitError, "Rate limited")
    end

    it "raises ConnectionError on network timeout" do
      stub_request(:get, "https://queue.fal.run/fal-ai/flux/requests/req-123/status")
        .to_timeout

      expect { client.queue.status("https://queue.fal.run/fal-ai/flux/requests/req-123/status") }
        .to raise_error(Fal::ConnectionError, /HTTP request failed/)
    end
  end
end
