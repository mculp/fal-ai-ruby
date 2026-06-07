# frozen_string_literal: true

require "English"
require "shellwords"

# These specs guard the public require entrypoints. spec_helper already loaded
# "fal" into this process, so an in-process `require` would be a no-op and prove
# nothing. We shell out to a pristine Ruby to exercise the real load path a user
# (or Bundler's auto-require) hits after `gem install fal-ai`.
RSpec.describe "library entrypoints" do
  lib = File.expand_path("../lib", __dir__)

  # `gem "fal-ai"` makes Bundler call `require "fal-ai"`, and the README tells
  # users to `require "fal-ai"`. Both must work, alongside the bare `require "fal"`.
  %w[fal-ai fal].each do |entrypoint|
    it "loads the gem via require #{entrypoint.inspect}" do
      script = "require #{entrypoint.inspect}; print Fal::VERSION"
      output = `#{RbConfig.ruby.shellescape} -I#{lib.shellescape} -e #{script.shellescape} 2>&1`

      expect($CHILD_STATUS).to be_success, "require #{entrypoint.inspect} failed:\n#{output}"
      expect(output).to eq(Fal::VERSION)
    end
  end
end
