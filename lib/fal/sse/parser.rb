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
        @pending_cr = false
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
        # A CR deferred from the final chunk is a real line terminator now that
        # the stream has ended; fold it in before emitting the last event.
        @buffer << "\n" if @pending_cr
        @pending_cr = false
        return if @buffer.empty?

        data = data_from(@buffer)
        @buffer.clear
        yield data unless data.nil?
      end

      private

      # Normalize CR/CRLF/LF endings to LF. A CR at the very end of a chunk is
      # held back — it may be the CR half of a CRLF the next chunk completes —
      # so a split "\r\n" is never mistaken for a blank-line event separator.
      def normalize(chunk)
        text = chunk.to_s
        text = "\r#{text}" if @pending_cr
        @pending_cr = text.end_with?("\r")
        text = text.chop if @pending_cr
        text.gsub("\r\n", "\n").tr("\r", "\n")
      end

      def data_from(raw_event)
        lines = raw_event.split("\n").select { |line| line.start_with?("data:") }
        return if lines.empty?

        lines.map { |line| line.delete_prefix("data:").delete_prefix(" ") }.join("\n")
      end
    end
  end
end
