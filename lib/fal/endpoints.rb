# frozen_string_literal: true

require "cgi"

module Fal
  # Value objects that turn an {EndpointId} (and, for queue requests, a request
  # id) into a concrete URL and HTTP method. Keeping URL construction here means
  # the rest of the gem never splits or interpolates endpoint strings by hand.
  module Endpoints
    # POST https://fal.run/{id} — synchronous run.
    class Run
      def initialize(endpoint_id:, base_url:)
        @endpoint_id = EndpointId.coerce(endpoint_id)
        @base_url = base_url
      end

      def url = "#{@base_url}/#{@endpoint_id}"
      def method = :post
    end

    # POST https://fal.run/{id}/stream — streaming (Server-Sent Events) run.
    class Stream
      def initialize(endpoint_id:, base_url:)
        @endpoint_id = EndpointId.coerce(endpoint_id)
        @base_url = base_url
      end

      def url = "#{@base_url}/#{@endpoint_id}/stream"
      def method = :post
    end

    # POST https://queue.fal.run/{id}[?fal_webhook=...] — enqueue a request.
    class Submit
      def initialize(endpoint_id:, base_url:, webhook_url: nil)
        @endpoint_id = EndpointId.coerce(endpoint_id)
        @base_url = base_url
        @webhook_url = webhook_url
      end

      def url
        base = "#{@base_url}/#{@endpoint_id}"
        return base unless @webhook_url

        "#{base}?fal_webhook=#{CGI.escape(@webhook_url)}"
      end

      def method = :post
    end

    # Base for the queue's per-request endpoints, which all live under
    # https://queue.fal.run/{app}/requests/{request_id}.
    class QueueRequest
      def initialize(endpoint_id:, request_id:, base_url:)
        @endpoint_id = EndpointId.coerce(endpoint_id)
        @request_id = request_id
        @base_url = base_url
      end

      private

      def request_url = "#{@base_url}/#{@endpoint_id}/requests/#{@request_id}"
    end

    # GET .../requests/{request_id}/status[?logs=1]
    class Status < QueueRequest
      def initialize(logs: false, **)
        super(**)
        @logs = logs
      end

      def url
        @logs ? "#{request_url}/status?logs=1" : "#{request_url}/status"
      end

      def method = :get
    end

    # GET .../requests/{request_id} — the completed result.
    class Result < QueueRequest
      def url = request_url
      def method = :get
    end

    # PUT .../requests/{request_id}/cancel
    class Cancel < QueueRequest
      def url = "#{request_url}/cancel"
      def method = :put
    end

    # POST {rest_url}/storage/upload/initiate — begins a presigned file upload.
    class StorageInitiate
      STORAGE_TYPE = "fal-cdn-v3"

      def initialize(base_url:)
        @base_url = base_url
      end

      def url = "#{@base_url}/storage/upload/initiate?storage_type=#{STORAGE_TYPE}"
      def method = :post
    end
  end
end
