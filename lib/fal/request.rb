# frozen_string_literal: true

require "json"

module Fal
  # Builds HTTP request components (headers, body).
  class Request
    CONTENT_TYPE = "application/json"
    USER_AGENT = "fal-ruby/#{VERSION}"

    def initialize(config:)
      @config = config
    end

    def headers
      {
        "Authorization" => "Key #{@config.api_key}",
        "Content-Type" => CONTENT_TYPE,
        "User-Agent" => USER_AGENT
      }
    end

    def body(input)
      JSON.generate(input)
    end
  end
end
