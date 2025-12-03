# frozen_string_literal: true

module Fal
  # Polls queue until completion, yielding status updates.
  class Subscriber
    def initialize(queue:, poll_interval:, timeout:)
      @queue = queue
      @poll_interval = poll_interval
      @timeout = timeout
    end

    def wait_for_completion(app_id, request_id, &on_update)
      deadline = Time.now + @timeout

      loop do
        check_timeout(deadline)
        status = @queue.status(app_id, request_id)
        yield_status(status, &on_update)
        return fetch_result(app_id, request_id) if status.completed?

        sleep(@poll_interval)
      end
    end

    private

    def check_timeout(deadline)
      return if Time.now < deadline

      raise TimeoutError, "Polling timed out after #{@timeout} seconds"
    end

    def yield_status(status, &on_update)
      on_update&.call(status)
    end

    def fetch_result(app_id, request_id)
      @queue.result(app_id, request_id)
    end
  end
end
