# frozen_string_literal: true

RSpec.describe Fal::Streaming do
  let(:config) { Fal::Configuration.new.tap { |c| c.api_key = "test-key" } }
  let(:connection) { instance_double(Fal::Connection) }
  let(:streaming) { described_class.new(connection: connection, config: config) }

  # Simulate the connection delivering raw SSE chunks to the streaming block.
  def stub_stream(*chunks)
    allow(connection).to receive(:stream) do |_endpoint, **, &on_chunk|
      chunks.each { |chunk| on_chunk.call(chunk) }
    end
  end

  it "yields each parsed event" do
    stub_stream(%(data: {"progress":0.5}\n\n), %(data: {"images":[]}\n\n))

    events = []
    streaming.stream("fal-ai/x", { prompt: "p" }) { |event| events << event }

    expect(events).to eq([{ "progress" => 0.5 }, { "images" => [] }])
  end

  it "returns the final event as the result" do
    stub_stream(%(data: {"progress":0.5}\n\n), %(data: {"images":["x"]}\n\n))

    expect(streaming.stream("fal-ai/x", { prompt: "p" })).to eq({ "images" => ["x"] })
  end

  it "POSTs the streaming endpoint on the run host with the input" do
    expect(connection).to receive(:stream) do |endpoint, body:, &_block|
      expect(endpoint).to be_a(Fal::Endpoints::Stream)
      expect(endpoint.url).to eq("https://fal.run/fal-ai/x/stream")
      expect(body).to eq({ prompt: "p" })
    end

    streaming.stream("fal-ai/x", { prompt: "p" })
  end

  it "passes non-JSON event data through unchanged" do
    stub_stream("data: plain text\n\n")

    expect(streaming.stream("fal-ai/x", {})).to eq("plain text")
  end
end
