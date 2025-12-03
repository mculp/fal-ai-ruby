# frozen_string_literal: true

require_relative "fal/version"
require_relative "fal/errors"
require_relative "fal/configuration"
require_relative "fal/endpoints"
require_relative "fal/status"
require_relative "fal/request"
require_relative "fal/response"
require_relative "fal/connection"
require_relative "fal/queue"
require_relative "fal/subscriber"
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

    def reset_configuration!
      @configuration = nil
    end
  end
end
