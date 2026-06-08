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

    def stream(app_id, input, &on_event)
      streaming.stream(app_id, input, &on_event)
    end

    # Uploads a local file (path or IO) to fal storage and returns its public URL.
    def upload(file, content_type: nil, file_name: nil)
      storage.upload(file, content_type: content_type, file_name: file_name)
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

    def streaming
      @streaming ||= Streaming.new(connection: @connection, config: @config)
    end

    def storage
      @storage ||= Storage.new(connection: @connection, config: @config)
    end
  end
end
