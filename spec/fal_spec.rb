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

    it "resets the memoized default client" do
      Fal.configure { |c| c.api_key = "test-key" }
      original = Fal.default_client

      Fal.reset_configuration!
      Fal.configure { |c| c.api_key = "test-key" }

      expect(Fal.default_client).not_to be(original)
    end
  end

  describe "module-level convenience methods" do
    before { Fal.configure { |c| c.api_key = "test-key" } }

    it ".default_client memoizes a single client" do
      expect(Fal.default_client).to be(Fal.default_client)
    end

    it ".run delegates to the default client" do
      allow(Fal).to receive(:default_client)
        .and_return(instance_double(Fal::Client, run: { "ok" => true }))

      expect(Fal.run("fal-ai/x", { a: 1 })).to eq({ "ok" => true })
    end

    it ".upload delegates to the default client" do
      allow(Fal).to receive(:default_client)
        .and_return(instance_double(Fal::Client, upload: "https://fal.media/x"))

      expect(Fal.upload("pic.png")).to eq("https://fal.media/x")
    end

    it ".queue delegates to the default client" do
      queue = instance_double(Fal::Queue)
      allow(Fal).to receive(:default_client).and_return(instance_double(Fal::Client, queue: queue))

      expect(Fal.queue).to be(queue)
    end
  end
end
