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

    def error_message
      data["detail"] || data["message"] || "Unknown error"
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
