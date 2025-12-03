# frozen_string_literal: true

module Fal
  # Base error for all Fal errors
  class Error < StandardError; end

  # Raised when configuration is invalid or missing
  class ConfigurationError < Error; end

  # Raised when HTTP connection fails
  class ConnectionError < Error
    attr_reader :original_error

    def initialize(message, original_error: nil)
      super(message)
      @original_error = original_error
    end
  end

  # Base class for API errors (non-2xx responses)
  class ApiError < Error
    attr_reader :status_code, :response_body

    def initialize(message, status_code:, response_body: nil)
      super(message)
      @status_code = status_code
      @response_body = response_body
    end
  end

  # 401 Unauthorized
  class AuthenticationError < ApiError; end

  # 404 Not Found
  class NotFoundError < ApiError; end

  # 429 Too Many Requests
  class RateLimitError < ApiError; end

  # 5xx Server Errors
  class ServerError < ApiError; end

  # Raised when polling times out
  class TimeoutError < Error; end
end
