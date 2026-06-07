# frozen_string_literal: true

require "json"

module Fal
  # Streams events from a streaming-capable model using Server-Sent Events.
  # Yields each event (partial results and progress) as it arrives, and returns
  # the final event — the completed result.
  class Streaming
    def initialize(connection:, config:)
      @connection = connection
      @config = config
    end

    def stream(app_id, input, &block)
      endpoint = Endpoints::Stream.new(endpoint_id: app_id, base_url: @config.run_url)
      events = collect_events(endpoint, input, &block)
      raise Error, "stream produced no events" if events.empty?

      events.last
    end

    private

    def collect_events(endpoint, input, &block)
      events = []
      parser = Sse::Parser.new
      @connection.stream(endpoint, body: input) do |chunk|
        parser.feed(chunk) { |data| events << emit(data, &block) }
      end
      parser.flush { |data| events << emit(data, &block) }
      events
    end

    def emit(data, &block)
      event = parse(data)
      block&.call(event)
      event
    end

    def parse(data)
      JSON.parse(data)
    rescue JSON::ParserError
      data
    end
  end
end
