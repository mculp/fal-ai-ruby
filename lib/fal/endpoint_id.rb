# frozen_string_literal: true

module Fal
  # A model endpoint id, e.g. "fal-ai/flux/schnell".
  #
  # The full id addresses synchronous run, queue submit, and streaming. The
  # queue's per-request URLs, however, live under the *application* — the owner
  # and alias only — so "fal-ai/flux/schnell" submits under the full path but is
  # polled under "fal-ai/flux". {#app} encapsulates that distinction so the rest
  # of the gem never splits endpoint strings by hand.
  class EndpointId
    # Namespaces whose application path keeps a third (namespace) segment.
    NAMESPACES = %w[workflows comfy].freeze

    def self.coerce(value)
      value.is_a?(self) ? value : new(value)
    end

    def initialize(id)
      @id = id.to_s
    end

    attr_reader :id
    alias to_s id

    # The queue application path: owner/alias, prefixed by a namespace if present.
    def app
      segments = id.split("/")
      app_segment_count = NAMESPACES.include?(segments.first) ? 3 : 2
      segments.take(app_segment_count).join("/")
    end

    def ==(other)
      other.is_a?(EndpointId) && other.id == id
    end
    alias eql? ==

    def hash
      id.hash
    end
  end
end
