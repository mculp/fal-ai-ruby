# frozen_string_literal: true

module Fal
  # Queue operations: submit, status, result, cancel.
  #
  # Status, result, and cancel are addressed by (app_id, request_id) — the same
  # ergonomics as the official fal clients. The per-request URLs are built from
  # the app root (via {EndpointId}), so nested ids like "fal-ai/flux/schnell"
  # resolve to the correct "fal-ai/flux/requests/..." path.
  class Queue
    def initialize(connection:, config:)
      @connection = connection
      @config = config
    end

    def submit(app_id, input, webhook_url: nil)
      endpoint = Endpoints::Submit.new(
        endpoint_id: app_id, base_url: @config.queue_url, webhook_url: webhook_url
      )
      build_submit_response(app_id, @connection.post(endpoint, body: input))
    end

    def status(app_id, request_id, logs: false)
      endpoint = Endpoints::Status.new(
        endpoint_id: app_id, request_id: request_id, base_url: @config.queue_url, logs: logs
      )
      @connection.get(endpoint).to_status
    end

    def result(app_id, request_id)
      endpoint = Endpoints::Result.new(
        endpoint_id: app_id, request_id: request_id, base_url: @config.queue_url
      )
      @connection.get(endpoint).data
    end

    # Returns true once cancellation is requested, false when the request can no
    # longer be cancelled (HTTP 400, e.g. already completed). Other errors raise.
    def cancel(app_id, request_id)
      endpoint = Endpoints::Cancel.new(
        endpoint_id: app_id, request_id: request_id, base_url: @config.queue_url
      )
      @connection.put(endpoint)
      true
    rescue ApiError => e
      raise unless e.status_code == 400

      false
    end

    private

    def build_submit_response(app_id, response)
      SubmitResponse.new(
        app_id: app_id,
        request_id: require_request_id(response),
        status_url: response.status_url,
        response_url: response.response_url,
        cancel_url: response.cancel_url
      )
    end

    def require_request_id(response)
      response.request_id ||
        raise(Error, "fal queue response did not include a request_id")
    end
  end

  # Value object returned by {Queue#submit}. Carries the request id plus the
  # status, response, and cancel URLs the API returned.
  SubmitResponse = Struct.new(
    :app_id, :request_id, :status_url, :response_url, :cancel_url, keyword_init: true
  )
end
