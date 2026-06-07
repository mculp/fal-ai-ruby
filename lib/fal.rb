# frozen_string_literal: true

require_relative "fal/version"
require_relative "fal/errors"
require_relative "fal/configuration"
require_relative "fal/endpoint_id"
require_relative "fal/endpoints"
require_relative "fal/sse/parser"
require_relative "fal/status"
require_relative "fal/request"
require_relative "fal/response"
require_relative "fal/connection"
require_relative "fal/queue"
require_relative "fal/subscriber"
require_relative "fal/streaming"
require_relative "fal/storage"
require_relative "fal/client"

# Ruby client for fal.ai Model APIs
#
# @example
#   Fal.configure do |config|
#     config.api_key = "your-api-key"
#   end
#
#   client = Fal.client
#   result = client.run("fal-ai/flux/dev", { prompt: "a cat" })
module Fal
  class << self
    def configure
      yield(configuration)
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def client(config: configuration)
      Client.new(config: config)
    end

    # A memoized client over the global configuration, used by the module-level
    # convenience methods below.
    def default_client
      @default_client ||= client
    end

    def run(...) = default_client.run(...)
    def subscribe(...) = default_client.subscribe(...)
    def stream(...) = default_client.stream(...)
    def upload(...) = default_client.upload(...)
    def queue = default_client.queue

    def reset_configuration!
      @configuration = nil
      @default_client = nil
    end
  end
end
