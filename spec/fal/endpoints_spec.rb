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

RSpec.describe Fal::Endpoints::Url do
  describe "#url" do
    it "returns the provided URL" do
      endpoint = Fal::Endpoints::Url.new(
        url: "https://queue.fal.run/fal-ai/flux/requests/abc-123/status"
      )

      expect(endpoint.url).to eq("https://queue.fal.run/fal-ai/flux/requests/abc-123/status")
    end
  end

  describe "#method" do
    it "returns :get" do
      endpoint = Fal::Endpoints::Url.new(
        url: "https://queue.fal.run/fal-ai/flux/requests/abc-123/status"
      )

      expect(endpoint.method).to eq(:get)
    end
  end
end
