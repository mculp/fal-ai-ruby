# frozen_string_literal: true

# Shim for Bundler auto-require.
# gem "fal-ai" triggers require "fal/ai" which loads this file.
require_relative "../fal"
