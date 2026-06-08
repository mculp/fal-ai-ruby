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
      final = collect_events(endpoint, input, &block)
      raise Error, "stream produced no events" if final.equal?(NO_EVENTS)

      final
    end

    private

    # Sentinel for "no event seen", distinct from a legitimately nil/false event.
    NO_EVENTS = Object.new
    private_constant :NO_EVENTS

    # Drives the SSE parser and keeps only the final event, so a long-running
    # stream stays O(1) in memory rather than retaining every partial result.
    def collect_events(endpoint, input, &block)
      parser = Sse::Parser.new
      last = NO_EVENTS
      record = ->(data) { last = emit(data, &block) }
      @connection.stream(endpoint, body: input) { |chunk| parser.feed(chunk, &record) }
      parser.flush(&record)
      last
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
