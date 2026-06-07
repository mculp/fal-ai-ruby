# frozen_string_literal: true

# Canonical entrypoint matching the gem name "fal-ai".
#
# `gem "fal-ai"` makes Bundler auto-require "fal-ai", and the README instructs
# users to `require "fal-ai"`. This file makes that work; the implementation
# lives under "fal".
require_relative "fal"
