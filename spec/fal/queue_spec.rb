# frozen_string_literal: true

RSpec.describe Fal::Queue do
  let(:config) do
    Fal::Configuration.new.tap do |c|
      c.api_key = "test-api-key"
    end
  end

  # Mock connection (not mocking Queue itself)
  let(:connection) { instance_double(Fal::Connection) }
  let(:queue) { Fal::Queue.new(connection: connection, config: config) }

  describe "#submit" do
    let(:response) do
      instance_double(
        Fal::Response,
        request_id: "req-123",
        status_url: "https://queue.fal.run/fal-ai/flux/requests/req-123/status",
        response_url: "https://queue.fal.run/fal-ai/flux/requests/req-123"
      )
    end

    before do
      allow(connection).to receive(:post).and_return(response)
    end

    it "returns a SubmitResponse with request_id and URLs" do
      result = queue.submit("fal-ai/flux/schnell", { prompt: "a cat" })

      expect(result).to be_a(Fal::SubmitResponse)
      expect(result.request_id).to eq("req-123")
      expect(result.status_url).to eq("https://queue.fal.run/fal-ai/flux/requests/req-123/status")
      expect(result.response_url).to eq("https://queue.fal.run/fal-ai/flux/requests/req-123")
    end

    it "posts to the submit endpoint with input" do
      expect(connection).to receive(:post) do |endpoint, body:|
        expect(endpoint).to be_a(Fal::Endpoints::Submit)
        expect(endpoint.url).to eq("https://queue.fal.run/fal-ai/flux/schnell")
        expect(body).to eq({ prompt: "a cat" })
      end.and_return(response)

      queue.submit("fal-ai/flux/schnell", { prompt: "a cat" })
    end
  end

  describe "#status" do
    let(:status) { Fal::Status::Queued.new({ "status" => "IN_QUEUE", "queue_position" => 2 }) }
    let(:response) do
      instance_double(Fal::Response, to_status: status)
    end

    before do
      allow(connection).to receive(:get).and_return(response)
    end

    it "returns a status object" do
      result = queue.status("https://queue.fal.run/fal-ai/flux/requests/req-123/status")

      expect(result).to be_a(Fal::Status::Queued)
    end

    it "gets the status URL directly" do
      expect(connection).to receive(:get) do |endpoint|
        expect(endpoint).to be_a(Fal::Endpoints::Url)
        expect(endpoint.url).to eq("https://queue.fal.run/fal-ai/flux/requests/req-123/status")
      end.and_return(response)

      queue.status("https://queue.fal.run/fal-ai/flux/requests/req-123/status")
    end
  end

  describe "#result" do
    let(:result_data) { { "images" => [{ "url" => "https://example.com/image.png" }] } }
    let(:response) do
      instance_double(Fal::Response, data: result_data)
    end

    before do
      allow(connection).to receive(:get).and_return(response)
    end

    it "returns the result data" do
      result = queue.result("https://queue.fal.run/fal-ai/flux/requests/req-123")

      expect(result).to eq(result_data)
    end

    it "gets the response URL directly" do
      expect(connection).to receive(:get) do |endpoint|
        expect(endpoint).to be_a(Fal::Endpoints::Url)
        expect(endpoint.url).to eq("https://queue.fal.run/fal-ai/flux/requests/req-123")
      end.and_return(response)

      queue.result("https://queue.fal.run/fal-ai/flux/requests/req-123")
    end
  end
end
