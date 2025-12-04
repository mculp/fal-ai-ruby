# frozen_string_literal: true

RSpec.describe Fal::VERSION do
  it "is a string" do
    expect(Fal::VERSION).to be_a(String)
  end

  it "follows semantic versioning format" do
    expect(Fal::VERSION).to match(/\A\d+\.\d+\.\d+/)
  end
end
