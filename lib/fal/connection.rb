# frozen_string_literal: true

require "http"

module Fal
  # HTTP connection wrapper using http.rb gem.
  # Dependency-injected for testability.
  class Connection
    def initialize(config:, http: HTTP)
      @config = config
      @http = http
      @request = Request.new(config: config)
    end

    def post(endpoint, body: nil)
      response = perform_post(endpoint, body)
      handle_response(response)
    end

    def get(endpoint)
      response = perform_get(endpoint)
      handle_response(response)
    end

    private

    def perform_post(endpoint, body)
      @http
        .headers(@request.headers)
        .timeout(@config.timeout)
        .post(endpoint.url, body: body ? @request.body(body) : nil)
    rescue HTTP::Error => e
      raise ConnectionError.new("HTTP request failed: #{e.message}", original_error: e)
    end

    def perform_get(endpoint)
      @http
        .headers(@request.headers)
        .timeout(@config.timeout)
        .get(endpoint.url)
    rescue HTTP::Error => e
      raise ConnectionError.new("HTTP request failed: #{e.message}", original_error: e)
    end

    def handle_response(http_response)
      response = Response.new(http_response)
      return response if response.success?

      raise_api_error(response)
    end

    def raise_api_error(response)
      error_class = error_class_for(response.status_code)
      raise error_class.new(
        response.error_message,
        status_code: response.status_code,
        response_body: response.data
      )
    end

    def error_class_for(status_code)
      case status_code
      when 401 then AuthenticationError
      when 404 then NotFoundError
      when 429 then RateLimitError
      when 500..599 then ServerError
      else ApiError
      end
    end
  end
end
