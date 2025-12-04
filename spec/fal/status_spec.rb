# frozen_string_literal: true

RSpec.describe Fal::Status::Base do
  let(:raw_data) { { "status" => "UNKNOWN", "extra" => "data" } }
  let(:status) { Fal::Status::Base.new(raw_data) }

  describe "#raw_data" do
    it "returns the raw data" do
      expect(status.raw_data).to eq(raw_data)
    end
  end

  describe "#queued?" do
    it "returns false" do
      expect(status.queued?).to be false
    end
  end

  describe "#in_progress?" do
    it "returns false" do
      expect(status.in_progress?).to be false
    end
  end

  describe "#completed?" do
    it "returns false" do
      expect(status.completed?).to be false
    end
  end
end

RSpec.describe Fal::Status::Queued do
  let(:raw_data) { { "status" => "IN_QUEUE", "queue_position" => 5 } }
  let(:status) { Fal::Status::Queued.new(raw_data) }

  describe "#position" do
    it "returns the queue position from queue_position" do
      expect(status.position).to eq(5)
    end

    it "returns position from alternative key" do
      status = Fal::Status::Queued.new({ "position" => 3 })

      expect(status.position).to eq(3)
    end
  end

  describe "#queued?" do
    it "returns true" do
      expect(status.queued?).to be true
    end
  end

  describe "#in_progress?" do
    it "returns false" do
      expect(status.in_progress?).to be false
    end
  end

  describe "#completed?" do
    it "returns false" do
      expect(status.completed?).to be false
    end
  end
end

RSpec.describe Fal::Status::InProgress do
  let(:raw_data) { { "status" => "IN_PROGRESS", "logs" => ["Starting...", "Processing..."] } }
  let(:status) { Fal::Status::InProgress.new(raw_data) }

  describe "#logs" do
    it "returns the logs array" do
      expect(status.logs).to eq(["Starting...", "Processing..."])
    end

    it "returns empty array when logs not present" do
      status = Fal::Status::InProgress.new({})

      expect(status.logs).to eq([])
    end
  end

  describe "#queued?" do
    it "returns false" do
      expect(status.queued?).to be false
    end
  end

  describe "#in_progress?" do
    it "returns true" do
      expect(status.in_progress?).to be true
    end
  end

  describe "#completed?" do
    it "returns false" do
      expect(status.completed?).to be false
    end
  end
end

RSpec.describe Fal::Status::Completed do
  let(:raw_data) do
    {
      "status" => "COMPLETED",
      "logs" => ["Done!"],
      "metrics" => { "inference_time" => 1.5 }
    }
  end
  let(:status) { Fal::Status::Completed.new(raw_data) }

  describe "#logs" do
    it "returns the logs array" do
      expect(status.logs).to eq(["Done!"])
    end

    it "returns empty array when logs not present" do
      status = Fal::Status::Completed.new({})

      expect(status.logs).to eq([])
    end
  end

  describe "#metrics" do
    it "returns the metrics hash" do
      expect(status.metrics).to eq({ "inference_time" => 1.5 })
    end

    it "returns empty hash when metrics not present" do
      status = Fal::Status::Completed.new({})

      expect(status.metrics).to eq({})
    end
  end

  describe "#queued?" do
    it "returns false" do
      expect(status.queued?).to be false
    end
  end

  describe "#in_progress?" do
    it "returns false" do
      expect(status.in_progress?).to be false
    end
  end

  describe "#completed?" do
    it "returns true" do
      expect(status.completed?).to be true
    end
  end
end
