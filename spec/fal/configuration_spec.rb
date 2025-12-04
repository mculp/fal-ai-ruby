# frozen_string_literal: true

RSpec.describe Fal::Configuration do
  describe "#initialize" do
    it "sets default timeout" do
      config = Fal::Configuration.new

      expect(config.timeout).to eq(300)
    end

    it "sets default poll_interval" do
      config = Fal::Configuration.new

      expect(config.poll_interval).to eq(0.5)
    end

    context "with FAL_KEY environment variable" do
      around do |example|
        original = ENV.fetch("FAL_KEY", nil)
        ENV["FAL_KEY"] = "env-api-key"
        example.run
        ENV["FAL_KEY"] = original
      end

      it "uses FAL_KEY from environment" do
        config = Fal::Configuration.new

        expect(config.api_key).to eq("env-api-key")
      end
    end

    context "without FAL_KEY environment variable" do
      around do |example|
        original = ENV.fetch("FAL_KEY", nil)
        ENV.delete("FAL_KEY")
        example.run
        ENV["FAL_KEY"] = original if original
      end

      it "raises ConfigurationError when accessing api_key" do
        config = Fal::Configuration.new

        expect { config.api_key }.to raise_error(Fal::ConfigurationError)
      end
    end
  end

  describe "#api_key=" do
    it "sets the API key" do
      config = Fal::Configuration.new
      config.api_key = "my-api-key"

      expect(config.api_key).to eq("my-api-key")
    end
  end

  describe "#timeout=" do
    it "sets the timeout" do
      config = Fal::Configuration.new
      config.timeout = 600

      expect(config.timeout).to eq(600)
    end
  end

  describe "#poll_interval=" do
    it "sets the poll interval" do
      config = Fal::Configuration.new
      config.poll_interval = 1.0

      expect(config.poll_interval).to eq(1.0)
    end
  end

  describe "#run_url" do
    it "returns the run API URL" do
      config = Fal::Configuration.new

      expect(config.run_url).to eq("https://fal.run")
    end
  end

  describe "#queue_url" do
    it "returns the queue API URL" do
      config = Fal::Configuration.new

      expect(config.queue_url).to eq("https://queue.fal.run")
    end
  end
end
