# frozen_string_literal: true

require "open3"

# These specs guard the public require entrypoints. spec_helper already loaded
# "fal" into this process, so an in-process `require` would be a no-op and prove
# nothing. We shell out to a fresh Ruby to exercise the real load path a user
# (or Bundler's auto-require) hits after `gem install fal-ai`.
#
# stdout and stderr are captured separately on purpose: some Ruby + Bundler
# combinations print harmless warnings to stderr, and those must not be mistaken
# for the gem's own output.
RSpec.describe "library entrypoints" do
  lib = File.expand_path("../lib", __dir__)

  # `gem "fal-ai"` makes Bundler call `require "fal-ai"`, and the README tells
  # users to `require "fal-ai"`. Both must work, alongside the bare `require "fal"`.
  %w[fal-ai fal].each do |entrypoint|
    it "loads the gem via require #{entrypoint.inspect}" do
      script = "require #{entrypoint.inspect}; print Fal::VERSION"
      stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-I#{lib}", "-e", script)

      expect(status).to be_success, "require #{entrypoint.inspect} failed:\n#{stderr}"
      expect(stdout).to eq(Fal::VERSION)
    end
  end
end
