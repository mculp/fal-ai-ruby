# frozen_string_literal: true

require "webmock/rspec"

RSpec.describe Fal::Connection do
  let(:config) do
    Fal::Configuration.new.tap do |c|
      c.api_key = "test-api-key"
      c.timeout = 30
    end
  end
  let(:connection) { described_class.new(config: config) }

  let(:run_endpoint) do
    Fal::Endpoints::Run.new(endpoint_id: "fal-ai/flux", base_url: "https://fal.run")
  end
  let(:status_endpoint) do
    Fal::Endpoints::Status.new(
      endpoint_id: "fal-ai/flux/schnell", request_id: "abc-123", base_url: "https://queue.fal.run"
    )
  end

  describe "#post" do
    it "sends auth + JSON and returns a parsed Response" do
      stub = stub_request(:post, "https://fal.run/fal-ai/flux")
             .with(
               body: '{"prompt":"a cat"}',
               headers: { "Authorization" => "Key test-api-key", "Content-Type" => "application/json" }
             )
             .to_return(status: 200, body: '{"images":[]}')

      response = connection.post(run_endpoint, body: { prompt: "a cat" })

      expect(response).to be_a(Fal::Response)
      expect(response.data).to eq({ "images" => [] })
      expect(stub).to have_been_requested
    end

    it "omits the body when none is given" do
      stub_request(:post, "https://fal.run/fal-ai/flux").to_return(status: 200, body: "{}")

      expect(connection.post(run_endpoint)).to be_a(Fal::Response)
    end

    {
      401 => Fal::AuthenticationError, 404 => Fal::NotFoundError,
      429 => Fal::RateLimitError, 500 => Fal::ServerError, 418 => Fal::ApiError
    }.each do |status, error_class|
      it "raises #{error_class} on #{status}" do
        stub_request(:post, "https://fal.run/fal-ai/flux")
          .to_return(status: status, body: '{"detail":"nope"}')

        expect { connection.post(run_endpoint) }.to raise_error(error_class)
      end
    end

    it "wraps a network failure as ConnectionError carrying the original error" do
      stub_request(:post, "https://fal.run/fal-ai/flux").to_raise(Faraday::ConnectionFailed.new("boom"))

      expect { connection.post(run_endpoint) }
        .to raise_error(Fal::ConnectionError, /HTTP request failed/) do |error|
          expect(error.original_error).to be_a(Faraday::Error)
        end
    end
  end

  describe "#get" do
    it "GETs the endpoint URL and returns a Response" do
      stub = stub_request(:get, "https://queue.fal.run/fal-ai/flux/schnell/requests/abc-123/status")
             .to_return(status: 200, body: '{"status":"COMPLETED"}')

      expect(connection.get(status_endpoint)).to be_a(Fal::Response)
      expect(stub).to have_been_requested
    end
  end

  describe "#put" do
    let(:cancel_endpoint) do
      Fal::Endpoints::Cancel.new(
        endpoint_id: "fal-ai/flux/schnell", request_id: "abc-123", base_url: "https://queue.fal.run"
      )
    end

    it "PUTs the endpoint URL and returns a Response" do
      stub = stub_request(:put, "https://queue.fal.run/fal-ai/flux/schnell/requests/abc-123/cancel")
             .to_return(status: 202, body: '{"status":"CANCELLATION_REQUESTED"}')

      expect(connection.put(cancel_endpoint)).to be_a(Fal::Response)
      expect(stub).to have_been_requested
    end
  end

  describe "#stream" do
    let(:stream_endpoint) do
      Fal::Endpoints::Stream.new(endpoint_id: "fal-ai/flux", base_url: "https://fal.run")
    end

    it "yields body chunks and requests the event-stream content type" do
      stub_request(:post, "https://fal.run/fal-ai/flux/stream")
        .with(headers: { "Accept" => "text/event-stream" })
        .to_return(status: 200, body: "data: a\n\ndata: b\n\n")

      chunks = []
      connection.stream(stream_endpoint, body: { x: 1 }) { |chunk| chunks << chunk }

      expect(chunks.join).to eq("data: a\n\ndata: b\n\n")
    end

    it "raises without yielding on a non-2xx status, surfacing the server detail" do
      stub_request(:post, "https://fal.run/fal-ai/flux/stream")
        .to_return(status: 401, body: '{"detail":"bad key"}')

      yielded = []
      expect { connection.stream(stream_endpoint, body: {}) { |chunk| yielded << chunk } }
        .to raise_error(Fal::AuthenticationError, /bad key/)
      expect(yielded).to be_empty
    end
  end

  describe "#upload" do
    let(:url) { "https://upload.example/put/abc" }

    it "PUTs the raw body with the content type and no fal auth header" do
      stub = stub_request(:put, url)
             .with(body: "raw-bytes", headers: { "Content-Type" => "image/png" })
             .to_return(status: 200, body: "")

      connection.upload(url, body: "raw-bytes", content_type: "image/png")

      expect(stub).to have_been_requested
      expect(a_request(:put, url).with(headers: { "Authorization" => "Key test-api-key" }))
        .not_to have_been_made
    end

    it "raises an API error when the upload fails" do
      stub_request(:put, url).to_return(status: 403, body: "Forbidden")

      expect { connection.upload(url, body: "x", content_type: "text/plain") }
        .to raise_error(Fal::ApiError)
    end
  end
end
