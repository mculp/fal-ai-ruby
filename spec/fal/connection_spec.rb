# frozen_string_literal: true

RSpec.describe Fal::Connection do
  let(:config) do
    Fal::Configuration.new.tap do |c|
      c.api_key = "test-api-key"
      c.timeout = 30
    end
  end

  # Mock HTTP client (not mocking Connection itself)
  let(:mock_http) { double("HTTP") }
  let(:mock_http_with_headers) { double("HTTP with headers") }
  let(:mock_http_with_timeout) { double("HTTP with timeout") }

  let(:connection) { Fal::Connection.new(config: config, http: mock_http) }

  before do
    allow(mock_http).to receive(:headers).and_return(mock_http_with_headers)
    allow(mock_http_with_headers).to receive(:timeout).and_return(mock_http_with_timeout)
  end

  describe "#post" do
    let(:endpoint) do
      Fal::Endpoints::Run.new(endpoint_id: "fal-ai/flux", base_url: "https://fal.run")
    end

    context "with successful response" do
      let(:http_response) { double("HTTP::Response", status: 200, body: '{"images": []}') }

      before do
        allow(mock_http_with_timeout).to receive(:post).and_return(http_response)
      end

      it "returns a Response object" do
        response = connection.post(endpoint, body: { prompt: "a cat" })

        expect(response).to be_a(Fal::Response)
      end

      it "sends request to endpoint URL" do
        expect(mock_http_with_timeout).to receive(:post)
          .with("https://fal.run/fal-ai/flux", body: '{"prompt":"a cat"}')
          .and_return(http_response)

        connection.post(endpoint, body: { prompt: "a cat" })
      end

      it "omits the body when none is given" do
        expect(mock_http_with_timeout).to receive(:post)
          .with("https://fal.run/fal-ai/flux")
          .and_return(http_response)

        connection.post(endpoint, body: nil)
      end
    end

    context "with 401 response" do
      let(:http_response) { double("HTTP::Response", status: 401, body: '{"detail": "Invalid API key"}') }

      before do
        allow(mock_http_with_timeout).to receive(:post).and_return(http_response)
      end

      it "raises AuthenticationError" do
        expect { connection.post(endpoint) }
          .to raise_error(Fal::AuthenticationError)
      end
    end

    context "with 404 response" do
      let(:http_response) { double("HTTP::Response", status: 404, body: '{"detail": "Not found"}') }

      before do
        allow(mock_http_with_timeout).to receive(:post).and_return(http_response)
      end

      it "raises NotFoundError" do
        expect { connection.post(endpoint) }
          .to raise_error(Fal::NotFoundError)
      end
    end

    context "with 429 response" do
      let(:http_response) { double("HTTP::Response", status: 429, body: '{"detail": "Rate limited"}') }

      before do
        allow(mock_http_with_timeout).to receive(:post).and_return(http_response)
      end

      it "raises RateLimitError" do
        expect { connection.post(endpoint) }
          .to raise_error(Fal::RateLimitError)
      end
    end

    context "with 500 response" do
      let(:http_response) { double("HTTP::Response", status: 500, body: '{"detail": "Internal error"}') }

      before do
        allow(mock_http_with_timeout).to receive(:post).and_return(http_response)
      end

      it "raises ServerError" do
        expect { connection.post(endpoint) }
          .to raise_error(Fal::ServerError)
      end
    end

    context "with HTTP error" do
      before do
        allow(mock_http_with_timeout).to receive(:post)
          .and_raise(HTTP::Error.new("Connection refused"))
      end

      it "raises ConnectionError" do
        expect { connection.post(endpoint) }
          .to raise_error(Fal::ConnectionError, /HTTP request failed/)
      end

      it "includes original error" do
        expect { connection.post(endpoint) }
          .to raise_error do |error|
            expect(error.original_error).to be_a(HTTP::Error)
          end
      end
    end
  end

  describe "#get" do
    let(:endpoint) do
      Fal::Endpoints::Status.new(
        endpoint_id: "fal-ai/flux/schnell", request_id: "abc-123", base_url: "https://queue.fal.run"
      )
    end

    context "with successful response" do
      let(:http_response) { double("HTTP::Response", status: 200, body: '{"status": "COMPLETED"}') }

      before do
        allow(mock_http_with_timeout).to receive(:get).and_return(http_response)
      end

      it "returns a Response object" do
        response = connection.get(endpoint)

        expect(response).to be_a(Fal::Response)
      end

      it "sends request to endpoint URL" do
        expect(mock_http_with_timeout).to receive(:get)
          .with("https://queue.fal.run/fal-ai/flux/requests/abc-123/status")
          .and_return(http_response)

        connection.get(endpoint)
      end
    end

    context "with HTTP error" do
      before do
        allow(mock_http_with_timeout).to receive(:get)
          .and_raise(HTTP::Error.new("Timeout"))
      end

      it "raises ConnectionError" do
        expect { connection.get(endpoint) }
          .to raise_error(Fal::ConnectionError)
      end
    end
  end

  describe "#put" do
    let(:endpoint) do
      Fal::Endpoints::Cancel.new(
        endpoint_id: "fal-ai/flux/schnell", request_id: "abc-123", base_url: "https://queue.fal.run"
      )
    end

    context "with successful response" do
      let(:http_response) do
        double("HTTP::Response", status: 202, body: '{"status": "CANCELLATION_REQUESTED"}')
      end

      before do
        allow(mock_http_with_timeout).to receive(:put).and_return(http_response)
      end

      it "returns a Response object" do
        expect(connection.put(endpoint)).to be_a(Fal::Response)
      end

      it "sends a PUT to the endpoint URL" do
        expect(mock_http_with_timeout).to receive(:put)
          .with("https://queue.fal.run/fal-ai/flux/requests/abc-123/cancel")
          .and_return(http_response)

        connection.put(endpoint)
      end
    end

    context "with HTTP error" do
      before do
        allow(mock_http_with_timeout).to receive(:put)
          .and_raise(HTTP::Error.new("Connection refused"))
      end

      it "raises ConnectionError" do
        expect { connection.put(endpoint) }
          .to raise_error(Fal::ConnectionError)
      end
    end
  end

  describe "#stream" do
    let(:endpoint) do
      Fal::Endpoints::Stream.new(endpoint_id: "fal-ai/flux", base_url: "https://fal.run")
    end
    let(:body) { double("HTTP::Response::Body") }
    let(:http_response) { double("HTTP::Response", status: 200, body: body) }

    before do
      allow(mock_http_with_timeout).to receive(:post).and_return(http_response)
      allow(body).to receive(:each).and_yield("data: a\n\n").and_yield("data: b\n\n")
    end

    it "yields each chunk of the streamed body" do
      chunks = []
      connection.stream(endpoint, body: { prompt: "x" }) { |chunk| chunks << chunk }

      expect(chunks).to eq(["data: a\n\n", "data: b\n\n"])
    end

    it "requests the event-stream content type" do
      expect(mock_http).to receive(:headers)
        .with(hash_including("Accept" => "text/event-stream"))
        .and_return(mock_http_with_headers)

      received = []
      connection.stream(endpoint, body: { prompt: "x" }) { |chunk| received << chunk }
    end

    it "raises an API error before streaming when the status is not 2xx" do
      error_response = double("HTTP::Response", status: 401, body: '{"detail": "Invalid"}')
      allow(mock_http_with_timeout).to receive(:post).and_return(error_response)

      expect { connection.stream(endpoint, body: {}) }
        .to raise_error(Fal::AuthenticationError)
    end

    it "wraps a mid-stream HTTP error as ConnectionError" do
      allow(body).to receive(:each).and_raise(HTTP::Error.new("reset"))

      expect { connection.stream(endpoint, body: {}) }
        .to raise_error(Fal::ConnectionError)
    end
  end

  describe "#upload" do
    let(:http_response) { double("HTTP::Response", status: 200, body: "") }

    before do
      allow(mock_http).to receive(:timeout).and_return(mock_http_with_timeout)
      allow(mock_http_with_timeout).to receive(:put).and_return(http_response)
    end

    it "PUTs the raw body with the content type and no fal auth header" do
      expect(mock_http).not_to receive(:headers)
      expect(mock_http_with_timeout).to receive(:put)
        .with("https://upload.example/put/abc",
              body: "raw-bytes", headers: { "Content-Type" => "image/png" })
        .and_return(http_response)

      connection.upload("https://upload.example/put/abc", body: "raw-bytes", content_type: "image/png")
    end

    it "raises an API error when the upload fails" do
      error_response = double("HTTP::Response", status: 403, body: "Forbidden")
      allow(mock_http_with_timeout).to receive(:put).and_return(error_response)

      expect { connection.upload("https://upload.example/put/abc", body: "x", content_type: "text/plain") }
        .to raise_error(Fal::ApiError)
    end
  end
end
