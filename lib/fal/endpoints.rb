# frozen_string_literal: true

module Fal
  module Endpoints
    # Endpoint for synchronous run: POST https://fal.run/{app_id}
    class Run
      def initialize(app_id:, base_url:)
        @app_id = app_id
        @base_url = base_url
      end

      def url
        "#{@base_url}/#{@app_id}"
      end

      def method
        :post
      end
    end

    # Endpoint for queue submit: POST https://queue.fal.run/{app_id}
    class Submit
      def initialize(app_id:, base_url:)
        @app_id = app_id
        @base_url = base_url
      end

      def url
        "#{@base_url}/#{@app_id}"
      end

      def method
        :post
      end
    end

    # Endpoint for queue status: GET https://queue.fal.run/{app_id}/requests/{request_id}/status
    class Status
      def initialize(app_id:, request_id:, base_url:)
        @app_id = app_id
        @request_id = request_id
        @base_url = base_url
      end

      def url
        "#{@base_url}/#{@app_id}/requests/#{@request_id}/status"
      end

      def method
        :get
      end
    end

    # Endpoint for queue result: GET https://queue.fal.run/{app_id}/requests/{request_id}
    class Result
      def initialize(app_id:, request_id:, base_url:)
        @app_id = app_id
        @request_id = request_id
        @base_url = base_url
      end

      def url
        "#{@base_url}/#{@app_id}/requests/#{@request_id}"
      end

      def method
        :get
      end
    end
  end
end
