# frozen_string_literal: true

module Fal
  module Sse
    # Incremental Server-Sent Events parser. Feed it raw response chunks; it
    # buffers across chunk boundaries and yields the `data` payload of each
    # complete event (events are terminated by a blank line). Non-data fields
    # (comments, `event:`, `id:`) are ignored.
    class Parser
      def initialize
        @buffer = +""
      end

      def feed(chunk)
        @buffer << normalize(chunk)
        while (boundary = @buffer.index("\n\n"))
          data = data_from(@buffer.slice!(0, boundary + 2))
          yield data unless data.nil?
        end
      end

      # Emit any remaining buffered data as a final event. Servers may close the
      # connection after the last event without a trailing blank line; for fal
      # that final event is the completed result, so it must not be dropped.
      def flush
        return if @buffer.empty?

        data = data_from(@buffer)
        @buffer.clear
        yield data unless data.nil?
      end

      private

      def normalize(chunk)
        chunk.to_s.gsub("\r\n", "\n").tr("\r", "\n")
      end

      def data_from(raw_event)
        lines = raw_event.split("\n").select { |line| line.start_with?("data:") }
        return if lines.empty?

        lines.map { |line| line.delete_prefix("data:").delete_prefix(" ") }.join("\n")
      end
    end
  end
end
