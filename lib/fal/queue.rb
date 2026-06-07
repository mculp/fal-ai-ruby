# frozen_string_literal: true

module Fal
  # Queue operations: submit, status, result.
  class Queue
    def initialize(connection:, config:)
      @connection = connection
      @config = config
    end

    def submit(app_id, input)
      endpoint = Endpoints::Submit.new(app_id: app_id, base_url: @config.queue_url)
      response = @connection.post(endpoint, body: input)
      build_submit_response(response)
    end

    def status(status_url)
      endpoint = Endpoints::Url.new(url: status_url)
      response = @connection.get(endpoint)
      response.to_status
    end

    def result(response_url)
      endpoint = Endpoints::Url.new(url: response_url)
      response = @connection.get(endpoint)
      response.data
    end

    private

    def build_submit_response(response)
      SubmitResponse.new(
        request_id: response.request_id,
        status_url: require_field(response, :status_url),
        response_url: require_field(response, :response_url)
      )
    end

    def require_field(response, field)
      response.public_send(field) ||
        raise(Error, "API response missing #{field} for request #{response.request_id}")
    end
  end

  # Value object returned by Queue#submit
  SubmitResponse = Struct.new(:request_id, :status_url, :response_url, keyword_init: true)
end
