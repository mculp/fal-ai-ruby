# frozen_string_literal: true

module Fal
  # Holds configuration for the Fal client.
  #
  # @example
  #   Fal.configure do |config|
  #     config.api_key = "your-api-key"
  #     config.timeout = 300
  #   end
  class Configuration
    attr_accessor :timeout, :poll_interval
    attr_writer :api_key

    DEFAULT_TIMEOUT = 300
    DEFAULT_POLL_INTERVAL = 0.5
    RUN_HOST = "fal.run"
    QUEUE_HOST = "queue.fal.run"

    def initialize
      @api_key = ENV.fetch("FAL_KEY", nil)
      @timeout = DEFAULT_TIMEOUT
      @poll_interval = DEFAULT_POLL_INTERVAL
    end

    def api_key
      @api_key or raise ConfigurationError, "API key not configured. Set FAL_KEY or call Fal.configure"
    end

    def run_url
      "https://#{RUN_HOST}"
    end

    def queue_url
      "https://#{QUEUE_HOST}"
    end
  end
end
