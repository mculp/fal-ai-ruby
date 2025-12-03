# frozen_string_literal: true

module Fal
  module Status
    # Base class for all status types
    class Base
      attr_reader :raw_data

      def initialize(raw_data)
        @raw_data = raw_data
      end

      def queued?
        false
      end

      def in_progress?
        false
      end

      def completed?
        false
      end
    end

    # Request is queued, waiting to be processed
    class Queued < Base
      def position
        raw_data["queue_position"] || raw_data["position"]
      end

      def queued?
        true
      end
    end

    # Request is currently being processed
    class InProgress < Base
      def logs
        raw_data["logs"] || []
      end

      def in_progress?
        true
      end
    end

    # Request has completed successfully
    class Completed < Base
      def logs
        raw_data["logs"] || []
      end

      def metrics
        raw_data["metrics"] || {}
      end

      def completed?
        true
      end
    end
  end
end
