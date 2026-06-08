# frozen_string_literal: true

require "json"

module Fal
  # Parses HTTP responses and creates appropriate objects.
  class Response
    def initialize(http_response)
      @http_response = http_response
    end

    def status_code
      @http_response.status.to_i
    end

    def success?
      status_code >= 200 && status_code < 300
    end

    def data
      @data ||= parse_body
    end

    def request_id
      data["request_id"]
    end

    def status_url
      data["status_url"]
    end

    def response_url
      data["response_url"]
    end

    def cancel_url
      data["cancel_url"]
    end

    # A non-Hash JSON body (a proxy/CDN may wrap an error as a top-level array or
    # scalar) has no detail/message keys and would raise TypeError if indexed by
    # string. Fall back to the raw response text so the caller still gets a
    # useful ApiError rather than a low-level TypeError.
    def error_message
      return truncate(raw_body) || "Unknown error" unless data.is_a?(Hash)

      data["detail"] || data["message"] || raw_error_text || "Unknown error"
    end

    def to_status
      status_class.new(data)
    end

    private

    def parse_body
      JSON.parse(@http_response.body.to_s)
    rescue JSON::ParserError
      { "raw" => @http_response.body.to_s }
    end

    # The raw body text from a parse failure (parse_body stashes it under "raw").
    def raw_error_text
      truncate(data["raw"])
    end

    def raw_body
      @http_response.body.to_s
    end

    # Bound a blank/oversized error string; nil when there is nothing useful.
    def truncate(text)
      return if text.nil? || text.strip.empty?

      text.length > 500 ? "#{text[0, 500]}…" : text
    end

    def status_class
      case data["status"]
      when "IN_QUEUE" then Status::Queued
      when "IN_PROGRESS" then Status::InProgress
      when "COMPLETED" then Status::Completed
      else Status::Base
      end
    end
  end
end
