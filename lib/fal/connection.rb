# frozen_string_literal: true

require "http"

module Fal
  # HTTP connection wrapper using the http.rb gem.
  # Dependency-injected for testability.
  class Connection
    def initialize(config:, http: HTTP)
      @config = config
      @http = http
      @request = Request.new(config: config)
    end

    def post(endpoint, body: nil)
      request(:post, endpoint, body: body)
    end

    def get(endpoint)
      request(:get, endpoint)
    end

    def put(endpoint, body: nil)
      request(:put, endpoint, body: body)
    end

    # Streams a Server-Sent Events response, yielding each raw body chunk.
    def stream(endpoint, body: nil, &on_chunk)
      http_response = send_streaming_request(endpoint, body)
      ensure_success(http_response)
      stream_body(http_response, &on_chunk)
    end

    # Uploads raw bytes to a presigned URL. These URLs carry their own auth, so
    # this deliberately sends no fal Authorization header — only the content type.
    def upload(url, body:, content_type:)
      http_response = perform_upload(url, body, content_type)
      ensure_success(http_response)
      http_response
    end

    private

    def perform_upload(url, body, content_type)
      @http
        .timeout(@config.timeout)
        .put(url, body: body, headers: { "Content-Type" => content_type })
    rescue HTTP::Error => e
      raise ConnectionError.new("HTTP request failed: #{e.message}", original_error: e)
    end

    def send_streaming_request(endpoint, body)
      @http
        .headers(@request.headers.merge("Accept" => "text/event-stream"))
        .timeout(@config.timeout)
        .public_send(endpoint.method, endpoint.url, **body_options(body))
    rescue HTTP::Error => e
      raise ConnectionError.new("HTTP request failed: #{e.message}", original_error: e)
    end

    def ensure_success(http_response)
      response = Response.new(http_response)
      raise_api_error(response) unless response.success?
    end

    def stream_body(http_response, &on_chunk)
      http_response.body.each(&on_chunk)
    rescue HTTP::Error => e
      raise ConnectionError.new("HTTP stream interrupted: #{e.message}", original_error: e)
    end

    def request(verb, endpoint, body: nil)
      handle_response(perform(verb, endpoint, body))
    end

    def perform(verb, endpoint, body)
      @http
        .headers(@request.headers)
        .timeout(@config.timeout)
        .public_send(verb, endpoint.url, **body_options(body))
    rescue HTTP::Error => e
      raise ConnectionError.new("HTTP request failed: #{e.message}", original_error: e)
    end

    def body_options(body)
      body ? { body: @request.body(body) } : {}
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
