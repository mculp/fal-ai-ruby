# frozen_string_literal: true

require "faraday"
require "json"

module Fal
  # HTTP transport built on Faraday. Faraday is pure Ruby (its default adapter is
  # the stdlib net/http), so the gem installs with no native extensions on any
  # Ruby. The Faraday object is injectable for testing.
  class Connection
    def initialize(config:, faraday: nil)
      @config = config
      @request = Request.new(config: config)
      @faraday = faraday || build_faraday
    end

    def post(endpoint, body: nil)
      json_request(endpoint, body)
    end

    def get(endpoint)
      json_request(endpoint, nil)
    end

    def put(endpoint, body: nil)
      json_request(endpoint, body)
    end

    # Streams a Server-Sent Events response, yielding each raw body chunk for a
    # 2xx response. Non-2xx responses raise the matching API error instead.
    def stream(endpoint, body: nil, &on_chunk)
      raise ArgumentError, "stream requires a block to receive chunks" unless block_given?

      error_body = +""
      response = perform(endpoint.method, endpoint.url) do |req|
        req.headers = @request.headers.merge("Accept" => "text/event-stream")
        req.body = @request.body(body) if body
        req.options.on_data = chunk_collector(error_body, &on_chunk)
      end
      ensure_streamed_success(response, error_body)
    end

    # Uploads raw bytes to a presigned URL. These URLs carry their own auth, so
    # this sends no fal Authorization header — only the content type.
    def upload(url, body:, content_type:)
      response = perform(:put, url) do |req|
        req.headers["Content-Type"] = content_type
        req.body = body
      end
      ensure_success(response)
      Response.new(response)
    end

    private

    def json_request(endpoint, body)
      response = perform(endpoint.method, endpoint.url) do |req|
        req.headers = @request.headers
        req.body = @request.body(body) if body
      end
      handle_response(response)
    end

    def perform(verb, url, &block)
      @faraday.public_send(verb, url, &block)
    rescue Faraday::Error => e
      raise ConnectionError.new("HTTP request failed: #{e.message}", original_error: e)
    end

    # The net/http adapter populates env.status before it streams the body, so
    # success chunks reach the caller and error chunks are buffered for the
    # message. A nil status (a non-default adapter that hasn't set it yet) is
    # treated as success rather than swallowed — a genuine error is still caught
    # afterwards by ensure_streamed_success.
    def chunk_collector(error_body, &on_chunk)
      proc do |chunk, _bytes, env|
        status = env.status
        if status.nil? || (200..299).cover?(status)
          on_chunk.call(chunk)
        else
          error_body << chunk
        end
      end
    end

    def ensure_streamed_success(response, error_body)
      return if response.success?

      status = response.status
      raise ApiError.for(
        streamed_error_message(error_body, status),
        status_code: status,
        response_body: error_body
      )
    end

    def streamed_error_message(error_body, status)
      json_error_detail(error_body) ||
        presence(error_body) ||
        "Request failed with status #{status}"
    end

    def json_error_detail(error_body)
      return if error_body.to_s.empty?

      parsed = JSON.parse(error_body)
      return unless parsed.is_a?(Hash)

      parsed["detail"] || parsed["message"]
    rescue JSON::ParserError
      nil
    end

    def presence(string)
      string unless string.to_s.strip.empty?
    end

    def build_faraday
      Faraday.new(request: { timeout: @config.timeout })
    end

    def handle_response(faraday_response)
      response = Response.new(faraday_response)
      return response if response.success?

      raise_api_error(response)
    end

    def ensure_success(faraday_response)
      response = Response.new(faraday_response)
      raise_api_error(response) unless response.success?
    end

    def raise_api_error(response)
      raise ApiError.for(
        response.error_message,
        status_code: response.status_code,
        response_body: response.data
      )
    end
  end
end
