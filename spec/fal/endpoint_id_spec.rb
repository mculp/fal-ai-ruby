# frozen_string_literal: true

RSpec.describe Fal::EndpointId do
  describe "#to_s" do
    it "preserves the full endpoint id (used for run/submit/stream URLs)" do
      expect(described_class.new("fal-ai/flux/schnell").to_s).to eq("fal-ai/flux/schnell")
    end
  end

  describe "#app (the queue application path)" do
    it "is the full id when there is no variant" do
      expect(described_class.new("fal-ai/fast-sdxl").app).to eq("fal-ai/fast-sdxl")
    end

    it "drops the variant suffix" do
      # The queue is per-app: fal-ai/flux/schnell submits under the full path but
      # its request URLs live under fal-ai/flux.
      expect(described_class.new("fal-ai/flux/schnell").app).to eq("fal-ai/flux")
    end

    it "drops a deeply nested variant" do
      id = "fal-ai/kling-video/v1.5/pro/image-to-video"
      expect(described_class.new(id).app).to eq("fal-ai/kling-video")
    end

    it "keeps three segments for the comfy namespace" do
      expect(described_class.new("comfy/fal-ai/flux").app).to eq("comfy/fal-ai/flux")
    end

    it "keeps three segments for the workflows namespace" do
      expect(described_class.new("workflows/me/my-flow/run").app).to eq("workflows/me/my-flow")
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
end
