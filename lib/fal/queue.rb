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
      response.request_id
    end

    def status(app_id, request_id)
      endpoint = Endpoints::Status.new(
        app_id: app_id,
        request_id: request_id,
        base_url: @config.queue_url
      )
      response = @connection.get(endpoint)
      response.to_status
    end

    def result(app_id, request_id)
      endpoint = Endpoints::Result.new(
        app_id: app_id,
        request_id: request_id,
        base_url: @config.queue_url
      )
      response = @connection.get(endpoint)
      response.data
    end
  end
end
