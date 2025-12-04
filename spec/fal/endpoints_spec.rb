# frozen_string_literal: true

RSpec.describe Fal::Endpoints::Run do
  describe "#url" do
    it "returns the run endpoint URL" do
      endpoint = Fal::Endpoints::Run.new(
        app_id: "fal-ai/flux/dev",
        base_url: "https://fal.run"
      )

      expect(endpoint.url).to eq("https://fal.run/fal-ai/flux/dev")
    end
  end

  describe "#method" do
    it "returns :post" do
      endpoint = Fal::Endpoints::Run.new(
        app_id: "fal-ai/flux/dev",
        base_url: "https://fal.run"
      )

      expect(endpoint.method).to eq(:post)
    end
  end
end

RSpec.describe Fal::Endpoints::Submit do
  describe "#url" do
    it "returns the queue submit endpoint URL" do
      endpoint = Fal::Endpoints::Submit.new(
        app_id: "fal-ai/flux/dev",
        base_url: "https://queue.fal.run"
      )

      expect(endpoint.url).to eq("https://queue.fal.run/fal-ai/flux/dev")
    end
  end

  describe "#method" do
    it "returns :post" do
      endpoint = Fal::Endpoints::Submit.new(
        app_id: "fal-ai/flux/dev",
        base_url: "https://queue.fal.run"
      )

      expect(endpoint.method).to eq(:post)
    end
  end
end

RSpec.describe Fal::Endpoints::Status do
  describe "#url" do
    it "returns the queue status endpoint URL" do
      endpoint = Fal::Endpoints::Status.new(
        app_id: "fal-ai/flux/dev",
        request_id: "abc-123",
        base_url: "https://queue.fal.run"
      )

      expect(endpoint.url).to eq("https://queue.fal.run/fal-ai/flux/dev/requests/abc-123/status")
    end
  end

  describe "#method" do
    it "returns :get" do
      endpoint = Fal::Endpoints::Status.new(
        app_id: "fal-ai/flux/dev",
        request_id: "abc-123",
        base_url: "https://queue.fal.run"
      )

      expect(endpoint.method).to eq(:get)
    end
  end
end

RSpec.describe Fal::Endpoints::Result do
  describe "#url" do
    it "returns the queue result endpoint URL" do
      endpoint = Fal::Endpoints::Result.new(
        app_id: "fal-ai/flux/dev",
        request_id: "abc-123",
        base_url: "https://queue.fal.run"
      )

      expect(endpoint.url).to eq("https://queue.fal.run/fal-ai/flux/dev/requests/abc-123")
    end
  end

  describe "#method" do
    it "returns :get" do
      endpoint = Fal::Endpoints::Result.new(
        app_id: "fal-ai/flux/dev",
        request_id: "abc-123",
        base_url: "https://queue.fal.run"
      )

      expect(endpoint.method).to eq(:get)
    end
  end
end
