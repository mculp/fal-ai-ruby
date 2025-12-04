# frozen_string_literal: true

RSpec.describe Fal do
  after do
    Fal.reset_configuration!
  end

  describe ".configure" do
    it "yields configuration to block" do
      Fal.configure do |config|
        config.api_key = "test-key"
      end

      expect(Fal.configuration.api_key).to eq("test-key")
    end
  end

  describe ".configuration" do
    it "returns a Configuration instance" do
      expect(Fal.configuration).to be_a(Fal::Configuration)
    end

    it "returns the same instance on multiple calls" do
      expect(Fal.configuration).to be(Fal.configuration)
    end
  end

  describe ".client" do
    it "returns a Client instance" do
      Fal.configure { |c| c.api_key = "test-key" }

      expect(Fal.client).to be_a(Fal::Client)
    end

    it "uses default configuration" do
      Fal.configure { |c| c.api_key = "test-key" }
      client = Fal.client

      expect(client).to be_a(Fal::Client)
    end

    it "accepts custom configuration" do
      custom_config = Fal::Configuration.new
      custom_config.api_key = "custom-key"

      client = Fal.client(config: custom_config)

      expect(client).to be_a(Fal::Client)
    end
  end

  describe ".reset_configuration!" do
    it "resets configuration to nil" do
      Fal.configure { |c| c.api_key = "test-key" }
      original = Fal.configuration

      Fal.reset_configuration!

      expect(Fal.configuration).not_to be(original)
    end
  end
end
