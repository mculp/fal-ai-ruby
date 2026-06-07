# frozen_string_literal: true

RSpec.describe Fal::Endpoints do
  let(:run_url) { "https://fal.run" }
  let(:queue_url) { "https://queue.fal.run" }

  describe Fal::Endpoints::Run do
    it "POSTs the full endpoint id on the run host" do
      endpoint = described_class.new(endpoint_id: "fal-ai/flux/dev", base_url: run_url)

      expect(endpoint.url).to eq("https://fal.run/fal-ai/flux/dev")
      expect(endpoint.method).to eq(:post)
    end
  end

  describe Fal::Endpoints::Stream do
    it "POSTs the /stream path on the run host" do
      endpoint = described_class.new(endpoint_id: "fal-ai/flux/dev", base_url: run_url)

      expect(endpoint.url).to eq("https://fal.run/fal-ai/flux/dev/stream")
      expect(endpoint.method).to eq(:post)
    end
  end

  describe Fal::Endpoints::Submit do
    it "POSTs the full endpoint id on the queue host" do
      endpoint = described_class.new(endpoint_id: "fal-ai/flux/dev", base_url: queue_url)

      expect(endpoint.url).to eq("https://queue.fal.run/fal-ai/flux/dev")
      expect(endpoint.method).to eq(:post)
    end

    it "appends a webhook as the fal_webhook query parameter (URL-encoded)" do
      endpoint = described_class.new(
        endpoint_id: "fal-ai/flux/dev",
        base_url: queue_url,
        webhook_url: "https://example.com/hook?x=1"
      )

      expect(endpoint.url).to eq(
        "https://queue.fal.run/fal-ai/flux/dev?fal_webhook=https%3A%2F%2Fexample.com%2Fhook%3Fx%3D1"
      )
    end
  end

  describe Fal::Endpoints::Status do
    it "GETs the request status under the app, dropping the variant" do
      endpoint = described_class.new(
        endpoint_id: "fal-ai/flux/schnell", request_id: "req-1", base_url: queue_url
      )

      expect(endpoint.url).to eq("https://queue.fal.run/fal-ai/flux/requests/req-1/status")
      expect(endpoint.method).to eq(:get)
    end

    it "requests logs when asked" do
      endpoint = described_class.new(
        endpoint_id: "fal-ai/flux/schnell", request_id: "req-1", base_url: queue_url, logs: true
      )

      expect(endpoint.url).to eq("https://queue.fal.run/fal-ai/flux/requests/req-1/status?logs=1")
    end
  end

  describe Fal::Endpoints::Result do
    it "GETs the request under the app" do
      endpoint = described_class.new(
        endpoint_id: "fal-ai/flux/schnell", request_id: "req-1", base_url: queue_url
      )

      expect(endpoint.url).to eq("https://queue.fal.run/fal-ai/flux/requests/req-1")
      expect(endpoint.method).to eq(:get)
    end
  end

  describe Fal::Endpoints::Cancel do
    it "PUTs the request cancel path under the app" do
      endpoint = described_class.new(
        endpoint_id: "fal-ai/flux/schnell", request_id: "req-1", base_url: queue_url
      )

      expect(endpoint.url).to eq("https://queue.fal.run/fal-ai/flux/requests/req-1/cancel")
      expect(endpoint.method).to eq(:put)
    end
  end
end
