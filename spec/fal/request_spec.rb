# frozen_string_literal: true

RSpec.describe Fal::Request do
  let(:config) do
    Fal::Configuration.new.tap do |c|
      c.api_key = "test-api-key"
    end
  end

  let(:request) { Fal::Request.new(config: config) }

  describe "#headers" do
    it "includes Authorization header with API key" do
      expect(request.headers["Authorization"]).to eq("Key test-api-key")
    end

    it "includes Content-Type header" do
      expect(request.headers["Content-Type"]).to eq("application/json")
    end

    it "includes User-Agent header" do
      expect(request.headers["User-Agent"]).to match(%r{^fal-ruby/})
    end

    it "includes version in User-Agent" do
      expect(request.headers["User-Agent"]).to include(Fal::VERSION)
    end
  end

  describe "#body" do
    it "serializes hash to JSON" do
      input = { prompt: "a cat", seed: 123 }

      expect(request.body(input)).to eq('{"prompt":"a cat","seed":123}')
    end

    it "handles nested hashes" do
      input = { options: { size: "large", format: "png" } }

      expect(request.body(input)).to eq('{"options":{"size":"large","format":"png"}}')
    end

    it "handles arrays" do
      input = { tags: %w[cat animal pet] }

      expect(request.body(input)).to eq('{"tags":["cat","animal","pet"]}')
    end
  end
end
