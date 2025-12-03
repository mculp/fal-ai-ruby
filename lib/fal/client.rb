# frozen_string_literal: true

module Fal
  # Main client facade providing public API.
  #
  # @example
  #   client = Fal.client
  #   result = client.run("fal-ai/flux/dev", { prompt: "a cat" })
  class Client
    def initialize(config:, connection: nil)
      @config = config
      @connection = connection || Connection.new(config: config)
    end

    def run(app_id, input)
      endpoint = Endpoints::Run.new(app_id: app_id, base_url: @config.run_url)
      response = @connection.post(endpoint, body: input)
      response.data
    end

    def subscribe(app_id, input, &on_queue_update)
      request_id = queue.submit(app_id, input)
      subscriber.wait_for_completion(app_id, request_id, &on_queue_update)
    end

    def queue
      @queue ||= Queue.new(connection: @connection, config: @config)
    end

    private

    def subscriber
      @subscriber ||= Subscriber.new(
        queue: queue,
        poll_interval: @config.poll_interval,
        timeout: @config.timeout
      )
    end
  end
end
