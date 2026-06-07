# frozen_string_literal: true

RSpec.describe Fal::Sse::Parser do
  def events_from(*chunks)
    parser = described_class.new
    collected = []
    chunks.each { |chunk| parser.feed(chunk) { |data| collected << data } }
    collected
  end

  it "yields the data payload of a complete event" do
    expect(events_from("data: {\"a\":1}\n\n")).to eq(['{"a":1}'])
  end

  it "yields nothing until an event is terminated by a blank line" do
    expect(events_from("data: {\"a\":1}\n")).to eq([])
  end

  it "reassembles an event split across chunks" do
    expect(events_from("data: {\"a\"", ":1}\n\n")).to eq(['{"a":1}'])
  end

  it "yields multiple events from a single chunk" do
    expect(events_from("data: one\n\ndata: two\n\n")).to eq(%w[one two])
  end

  it "ignores comments and non-data fields" do
    expect(events_from(": keep-alive\nevent: update\ndata: payload\n\n")).to eq(["payload"])
  end

  it "joins multi-line data with newlines" do
    expect(events_from("data: line1\ndata: line2\n\n")).to eq(["line1\nline2"])
  end

  it "tolerates CRLF line endings" do
    expect(events_from("data: hi\r\n\r\n")).to eq(["hi"])
  end

  it "skips events that carry no data field" do
    expect(events_from("event: ping\n\ndata: real\n\n")).to eq(["real"])
  end

  it "flushes a final event that has no trailing blank line" do
    parser = described_class.new
    collected = []
    parser.feed("data: {\"done\":true}\n") { |d| collected << d }
    expect(collected).to eq([])
    parser.flush { |d| collected << d }
    expect(collected).to eq(['{"done":true}'])
  end

  it "flushes nothing when the parser is empty" do
    parser = described_class.new
    collected = []
    parser.flush { |d| collected << d }
    expect(collected).to eq([])
  end

  it "flushes nothing when the buffer holds only a comment" do
    parser = described_class.new
    collected = []
    parser.feed(": keep-alive\n") { |d| collected << d }
    parser.flush { |d| collected << d }
    expect(collected).to eq([])
  end
end
