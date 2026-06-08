# frozen_string_literal: true

RSpec.describe Fal::EndpointId do
  describe "#to_s" do
    it "preserves the full endpoint id (used for run/submit/stream URLs)" do
      expect(described_class.new("fal-ai/flux/schnell").to_s).to eq("fal-ai/flux/schnell")
    end
  end

  describe ".coerce" do
    it "returns an EndpointId untouched" do
      id = described_class.new("fal-ai/flux")
      expect(described_class.coerce(id)).to be(id)
    end

    it "wraps a string" do
      expect(described_class.coerce("fal-ai/flux")).to eq(described_class.new("fal-ai/flux"))
    end
  end

  describe "value equality" do
    it "is equal to another EndpointId with the same id" do
      expect(described_class.new("fal-ai/flux")).to eq(described_class.new("fal-ai/flux"))
    end

    it "can be used as a hash key" do
      table = { described_class.new("fal-ai/flux") => :ok }
      expect(table[described_class.new("fal-ai/flux")]).to eq(:ok)
    end
  end

  describe "validation" do
    it "rejects a nil id rather than coercing it to an empty string" do
      expect { described_class.new(nil) }.to raise_error(ArgumentError, /blank/)
    end

    it "rejects a blank id" do
      expect { described_class.new("   ") }.to raise_error(ArgumentError, /blank/)
    end

    it "trims surrounding whitespace from a valid id" do
      expect(described_class.new("  fal-ai/flux  ").to_s).to eq("fal-ai/flux")
    end
  end
end
