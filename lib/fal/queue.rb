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

      status_url = response.status_url
      response_url = response.response_url

      raise Error, "API response missing status_url for request #{response.request_id}" unless status_url
      raise Error, "API response missing response_url for request #{response.request_id}" unless response_url

      SubmitResponse.new(
        request_id: response.request_id,
        status_url: status_url,
        response_url: response_url
      )
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
  end

  # Value object returned by Queue#submit
  SubmitResponse = Struct.new(:request_id, :status_url, :response_url, keyword_init: true)
end
