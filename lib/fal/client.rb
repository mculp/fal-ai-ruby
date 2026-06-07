# frozen_string_literal: true

module Fal
  # Main client facade providing the public API.
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
      endpoint = Endpoints::Run.new(endpoint_id: app_id, base_url: @config.run_url)
      response = @connection.post(endpoint, body: input)
      response.data
    end

    def subscribe(app_id, input, logs: false, webhook_url: nil, &on_queue_update)
      submit_response = queue.submit(app_id, input, webhook_url: webhook_url)
      subscriber.wait_for_completion(submit_response, logs: logs, &on_queue_update)
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
