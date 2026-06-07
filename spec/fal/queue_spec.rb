# frozen_string_literal: true

RSpec.describe Fal::Queue do
  let(:config) do
    Fal::Configuration.new.tap { |c| c.api_key = "test-api-key" }
  end

  # Mock connection (not mocking Queue itself).
  let(:connection) { instance_double(Fal::Connection) }
  let(:queue) { Fal::Queue.new(connection: connection, config: config) }

  describe "#submit" do
    let(:response) do
      instance_double(
        Fal::Response,
        request_id: "req-123",
        status_url: "https://queue.fal.run/fal-ai/flux/requests/req-123/status",
        response_url: "https://queue.fal.run/fal-ai/flux/requests/req-123",
        cancel_url: "https://queue.fal.run/fal-ai/flux/requests/req-123/cancel"
      )
    end

    before { allow(connection).to receive(:post).and_return(response) }

    it "returns a SubmitResponse carrying the app id, request id, and URLs" do
      result = queue.submit("fal-ai/flux/schnell", { prompt: "a cat" })

      expect(result).to be_a(Fal::SubmitResponse)
      expect(result.app_id).to eq("fal-ai/flux/schnell")
      expect(result.request_id).to eq("req-123")
      expect(result.status_url).to eq("https://queue.fal.run/fal-ai/flux/requests/req-123/status")
      expect(result.response_url).to eq("https://queue.fal.run/fal-ai/flux/requests/req-123")
      expect(result.cancel_url).to eq("https://queue.fal.run/fal-ai/flux/requests/req-123/cancel")
    end

    it "posts to the submit endpoint with the input" do
      expect(connection).to receive(:post) do |endpoint, body:|
        expect(endpoint).to be_a(Fal::Endpoints::Submit)
        expect(endpoint.url).to eq("https://queue.fal.run/fal-ai/flux/schnell")
        expect(body).to eq({ prompt: "a cat" })
      end.and_return(response)

      queue.submit("fal-ai/flux/schnell", { prompt: "a cat" })
    end

    it "attaches a webhook URL when given" do
      expect(connection).to receive(:post) do |endpoint, **_kwargs|
        expect(endpoint.url).to include("fal_webhook=")
      end.and_return(response)

      queue.submit("fal-ai/flux", { prompt: "a cat" }, webhook_url: "https://example.com/hook")
    end

    it "raises when the response has no request_id" do
      allow(response).to receive(:request_id).and_return(nil)

      expect { queue.submit("fal-ai/flux", {}) }.to raise_error(Fal::Error, /request_id/)
    end
  end

  describe "#status" do
    let(:status) { Fal::Status::Queued.new({ "status" => "IN_QUEUE", "queue_position" => 2 }) }
    let(:response) { instance_double(Fal::Response, to_status: status) }

    before { allow(connection).to receive(:get).and_return(response) }

    it "returns the parsed status" do
      expect(queue.status("fal-ai/flux/schnell", "req-123")).to be_a(Fal::Status::Queued)
    end

    it "GETs the status endpoint built from the app and request id" do
      expect(connection).to receive(:get) do |endpoint|
        expect(endpoint).to be_a(Fal::Endpoints::Status)
        expect(endpoint.url).to eq("https://queue.fal.run/fal-ai/flux/requests/req-123/status")
      end.and_return(response)

      queue.status("fal-ai/flux/schnell", "req-123")
    end

    it "requests logs when asked" do
      expect(connection).to receive(:get) do |endpoint|
        expect(endpoint.url).to end_with("/status?logs=1")
      end.and_return(response)

      queue.status("fal-ai/flux/schnell", "req-123", logs: true)
    end
  end

  describe "#result" do
    let(:result_data) { { "images" => [{ "url" => "https://example.com/image.png" }] } }
    let(:response) { instance_double(Fal::Response, data: result_data) }

    before { allow(connection).to receive(:get).and_return(response) }

    it "returns the result data" do
      expect(queue.result("fal-ai/flux/schnell", "req-123")).to eq(result_data)
    end

    it "GETs the result endpoint built from the app and request id" do
      expect(connection).to receive(:get) do |endpoint|
        expect(endpoint).to be_a(Fal::Endpoints::Result)
        expect(endpoint.url).to eq("https://queue.fal.run/fal-ai/flux/requests/req-123")
      end.and_return(response)

      queue.result("fal-ai/flux/schnell", "req-123")
    end
  end

  describe "#cancel" do
    it "PUTs the cancel endpoint and returns true on success" do
      expect(connection).to receive(:put) do |endpoint|
        expect(endpoint).to be_a(Fal::Endpoints::Cancel)
        expect(endpoint.url).to eq("https://queue.fal.run/fal-ai/flux/requests/req-123/cancel")
      end.and_return(instance_double(Fal::Response))

      expect(queue.cancel("fal-ai/flux/schnell", "req-123")).to be(true)
    end

    it "returns false when the request can no longer be cancelled (HTTP 400)" do
      allow(connection).to receive(:put)
        .and_raise(Fal::ApiError.new("Already completed", status_code: 400))

      expect(queue.cancel("fal-ai/flux/schnell", "req-123")).to be(false)
    end

    it "re-raises other API errors" do
      allow(connection).to receive(:put)
        .and_raise(Fal::NotFoundError.new("Not found", status_code: 404))

      expect { queue.cancel("fal-ai/flux/schnell", "req-123") }.to raise_error(Fal::NotFoundError)
    end
  end
end
