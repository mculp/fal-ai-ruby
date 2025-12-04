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
      Fal::Endpoints::Run.new(app_id: "fal-ai/flux", base_url: "https://fal.run")
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

      it "handles nil body" do
        expect(mock_http_with_timeout).to receive(:post)
          .with("https://fal.run/fal-ai/flux", body: nil)
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
        app_id: "fal-ai/flux",
        request_id: "abc-123",
        base_url: "https://queue.fal.run"
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
end
