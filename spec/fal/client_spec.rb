# frozen_string_literal: true

RSpec.describe Fal::Client do
  let(:config) do
    Fal::Configuration.new.tap do |c|
      c.api_key = "test-api-key"
      c.timeout = 30
      c.poll_interval = 0.01
    end
  end

  # Mock connection (not mocking Client itself)
  let(:connection) { instance_double(Fal::Connection) }
  let(:client) { Fal::Client.new(config: config, connection: connection) }

  describe "#run" do
    let(:result_data) { { "images" => [{ "url" => "https://example.com/image.png" }] } }
    let(:response) { instance_double(Fal::Response, data: result_data) }

    before do
      allow(connection).to receive(:post).and_return(response)
    end

    it "returns the result data" do
      result = client.run("fal-ai/flux", { prompt: "a cat" })

      expect(result).to eq(result_data)
    end

    it "posts to the run endpoint" do
      expect(connection).to receive(:post) do |endpoint, body:|
        expect(endpoint).to be_a(Fal::Endpoints::Run)
        expect(endpoint.url).to eq("https://fal.run/fal-ai/flux")
        expect(body).to eq({ prompt: "a cat" })
      end.and_return(response)

      client.run("fal-ai/flux", { prompt: "a cat" })
    end

    it "handles complex input" do
      input = {
        prompt: "a cat",
        seed: 123,
        options: { size: "large" }
      }

      expect(connection).to receive(:post)
        .with(anything, body: input)
        .and_return(response)

      client.run("fal-ai/flux", input)
    end
  end

  describe "#subscribe" do
    let(:request_id) { "req-123" }
    let(:result_data) { { "images" => [{ "url" => "https://example.com/image.png" }] } }

    let(:submit_response) { instance_double(Fal::Response, request_id: request_id) }
    let(:queued_status) { Fal::Status::Queued.new({ "status" => "IN_QUEUE", "queue_position" => 1 }) }
    let(:completed_status) { Fal::Status::Completed.new({ "status" => "COMPLETED" }) }
    let(:status_response_queued) { instance_double(Fal::Response, to_status: queued_status) }
    let(:status_response_completed) { instance_double(Fal::Response, to_status: completed_status) }
    let(:result_response) { instance_double(Fal::Response, data: result_data) }

    before do
      allow(connection).to receive(:post).and_return(submit_response)
      allow(connection).to receive(:get)
        .and_return(status_response_queued, status_response_completed, result_response)
    end

    it "returns the final result" do
      result = client.subscribe("fal-ai/flux", { prompt: "a cat" })

      expect(result).to eq(result_data)
    end

    it "yields status updates" do
      statuses = []
      client.subscribe("fal-ai/flux", { prompt: "a cat" }) { |s| statuses << s }

      expect(statuses.map(&:class)).to include(Fal::Status::Queued, Fal::Status::Completed)
    end

    it "submits to queue first" do
      expect(connection).to receive(:post) do |endpoint, **_kwargs|
        expect(endpoint).to be_a(Fal::Endpoints::Submit)
      end.and_return(submit_response)

      client.subscribe("fal-ai/flux", { prompt: "a cat" })
    end
  end

  describe "#queue" do
    it "returns a Queue instance" do
      expect(client.queue).to be_a(Fal::Queue)
    end

    it "returns the same instance on multiple calls" do
      expect(client.queue).to be(client.queue)
    end

    it "uses the same connection" do
      # Queue should use the injected connection
      queue = client.queue
      result_response = instance_double(Fal::Response, request_id: "req-123")

      expect(connection).to receive(:post).and_return(result_response)

      queue.submit("fal-ai/flux", { prompt: "test" })
    end
  end

  describe "initialization" do
    it "accepts config" do
      client = Fal::Client.new(config: config)

      expect(client).to be_a(Fal::Client)
    end

    it "accepts custom connection" do
      custom_connection = instance_double(Fal::Connection)
      client = Fal::Client.new(config: config, connection: custom_connection)

      result_response = instance_double(Fal::Response, data: {})
      allow(custom_connection).to receive(:post).and_return(result_response)

      client.run("fal-ai/flux", {})

      expect(custom_connection).to have_received(:post)
    end

    it "creates default connection when not provided" do
      client = Fal::Client.new(config: config)

      # Should not raise - creates its own connection
      expect(client.queue).to be_a(Fal::Queue)
    end
  end
end
