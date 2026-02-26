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

    # Endpoint wrapping a URL returned by the API (for status and result)
    class Url
      def initialize(url:)
        raise ArgumentError, "url cannot be nil" if url.nil?

        @url = url
      end

      attr_reader :url

      def method
        :get
      end
    end
  end
end
