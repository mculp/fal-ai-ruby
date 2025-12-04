# frozen_string_literal: true

RSpec.describe Fal::Response do
  # Create a simple mock HTTP response for testing
  # We're not mocking Response itself, just the HTTP library's response object
  let(:http_response) do
    double("HTTP::Response", status: status_code, body: body)
  end

  describe "#status_code" do
    let(:status_code) { 200 }
    let(:body) { '{"result": "success"}' }

    it "returns the HTTP status code as integer" do
      response = Fal::Response.new(http_response)

      expect(response.status_code).to eq(200)
    end
  end

  describe "#success?" do
    let(:body) { '{"result": "success"}' }

    context "with 2xx status" do
      [200, 201, 204].each do |code|
        it "returns true for #{code}" do
          http_response = double("HTTP::Response", status: code, body: body)
          response = Fal::Response.new(http_response)

          expect(response.success?).to be true
        end
      end
    end

    context "with non-2xx status" do
      [400, 401, 404, 500].each do |code|
        it "returns false for #{code}" do
          http_response = double("HTTP::Response", status: code, body: body)
          response = Fal::Response.new(http_response)

          expect(response.success?).to be false
        end
      end
    end
  end

  describe "#data" do
    let(:status_code) { 200 }

    context "with valid JSON body" do
      let(:body) { '{"images": [{"url": "https://example.com/image.png"}]}' }

      it "parses JSON body" do
        response = Fal::Response.new(http_response)

        expect(response.data).to eq({ "images" => [{ "url" => "https://example.com/image.png" }] })
      end
    end

    context "with invalid JSON body" do
      let(:body) { "not json" }

      it "returns raw body in hash" do
        response = Fal::Response.new(http_response)

        expect(response.data).to eq({ "raw" => "not json" })
      end
    end
  end

  describe "#request_id" do
    let(:status_code) { 200 }
    let(:body) { '{"request_id": "abc-123"}' }

    it "returns the request_id from data" do
      response = Fal::Response.new(http_response)

      expect(response.request_id).to eq("abc-123")
    end
  end

  describe "#error_message" do
    let(:status_code) { 400 }

    context "with detail key" do
      let(:body) { '{"detail": "Invalid prompt"}' }

      it "returns detail message" do
        response = Fal::Response.new(http_response)

        expect(response.error_message).to eq("Invalid prompt")
      end
    end

    context "with message key" do
      let(:body) { '{"message": "Bad request"}' }

      it "returns message" do
        response = Fal::Response.new(http_response)

        expect(response.error_message).to eq("Bad request")
      end
    end

    context "without error keys" do
      let(:body) { '{"foo": "bar"}' }

      it "returns unknown error" do
        response = Fal::Response.new(http_response)

        expect(response.error_message).to eq("Unknown error")
      end
    end
  end

  describe "#to_status" do
    let(:status_code) { 200 }

    context "with IN_QUEUE status" do
      let(:body) { '{"status": "IN_QUEUE", "queue_position": 3}' }

      it "returns Queued status" do
        response = Fal::Response.new(http_response)

        expect(response.to_status).to be_a(Fal::Status::Queued)
      end
    end

    context "with IN_PROGRESS status" do
      let(:body) { '{"status": "IN_PROGRESS", "logs": ["working..."]}' }

      it "returns InProgress status" do
        response = Fal::Response.new(http_response)

        expect(response.to_status).to be_a(Fal::Status::InProgress)
      end
    end

    context "with COMPLETED status" do
      let(:body) { '{"status": "COMPLETED"}' }

      it "returns Completed status" do
        response = Fal::Response.new(http_response)

        expect(response.to_status).to be_a(Fal::Status::Completed)
      end
    end

    context "with unknown status" do
      let(:body) { '{"status": "UNKNOWN"}' }

      it "returns Base status" do
        response = Fal::Response.new(http_response)

        expect(response.to_status).to be_a(Fal::Status::Base)
      end
    end
  end
end
