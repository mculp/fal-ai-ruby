# frozen_string_literal: true

RSpec.describe Fal::Subscriber do
  # Mock queue (not mocking Subscriber itself)
  let(:queue) { instance_double(Fal::Queue) }
  let(:poll_interval) { 0.01 } # Fast polling for tests
  let(:timeout) { 1 }

  let(:subscriber) do
    Fal::Subscriber.new(queue: queue, poll_interval: poll_interval, timeout: timeout)
  end

  describe "#wait_for_completion" do
    let(:app_id) { "fal-ai/flux" }
    let(:request_id) { "req-123" }
    let(:result_data) { { "images" => [{ "url" => "https://example.com/image.png" }] } }

    context "when immediately completed" do
      let(:completed_status) { Fal::Status::Completed.new({ "status" => "COMPLETED" }) }

      before do
        allow(queue).to receive(:status).and_return(completed_status)
        allow(queue).to receive(:result).and_return(result_data)
      end

      it "returns the result" do
        result = subscriber.wait_for_completion(app_id, request_id)

        expect(result).to eq(result_data)
      end

      it "yields the completed status" do
        statuses = []
        subscriber.wait_for_completion(app_id, request_id) { |s| statuses << s }

        expect(statuses).to eq([completed_status])
      end

      it "fetches the result after completion" do
        expect(queue).to receive(:result).with(app_id, request_id)

        subscriber.wait_for_completion(app_id, request_id)
      end
    end

    context "when queued then completed" do
      let(:queued_status) { Fal::Status::Queued.new({ "status" => "IN_QUEUE", "queue_position" => 2 }) }
      let(:in_progress_status) { Fal::Status::InProgress.new({ "status" => "IN_PROGRESS" }) }
      let(:completed_status) { Fal::Status::Completed.new({ "status" => "COMPLETED" }) }

      before do
        allow(queue).to receive(:status)
          .and_return(queued_status, in_progress_status, completed_status)
        allow(queue).to receive(:result).and_return(result_data)
      end

      it "polls until completed" do
        expect(queue).to receive(:status).exactly(3).times

        subscriber.wait_for_completion(app_id, request_id)
      end

      it "yields each status update" do
        statuses = []
        subscriber.wait_for_completion(app_id, request_id) { |s| statuses << s }

        expect(statuses.map(&:class)).to eq([
          Fal::Status::Queued,
          Fal::Status::InProgress,
          Fal::Status::Completed
        ])
      end
    end

    context "when timeout exceeded" do
      let(:queued_status) { Fal::Status::Queued.new({ "status" => "IN_QUEUE" }) }
      let(:subscriber) do
        Fal::Subscriber.new(queue: queue, poll_interval: 0.01, timeout: 0.02)
      end

      before do
        allow(queue).to receive(:status).and_return(queued_status)
      end

      it "raises TimeoutError" do
        expect { subscriber.wait_for_completion(app_id, request_id) }
          .to raise_error(Fal::TimeoutError, /timed out/)
      end
    end

    context "without block" do
      let(:completed_status) { Fal::Status::Completed.new({ "status" => "COMPLETED" }) }

      before do
        allow(queue).to receive(:status).and_return(completed_status)
        allow(queue).to receive(:result).and_return(result_data)
      end

      it "does not raise when no block given" do
        expect { subscriber.wait_for_completion(app_id, request_id) }
          .not_to raise_error
      end
    end
  end
end
