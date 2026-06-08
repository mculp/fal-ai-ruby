# frozen_string_literal: true

module Fal
  # A model endpoint id, e.g. "fal-ai/flux/schnell".
  #
  # A thin value wrapper around an endpoint id string. It exists so callers can
  # pass either a String or an EndpointId interchangeably; the full id addresses
  # every fal route (synchronous run, streaming, queue submit, and the queue's
  # per-request status/result/cancel URLs alike).
  class EndpointId
    def self.coerce(value)
      value.is_a?(self) ? value : new(value)
    end

    def initialize(id)
      @id = id.to_s.strip
      raise ArgumentError, "endpoint id must not be blank" if @id.empty?
    end

    attr_reader :id
    alias to_s id

    def ==(other)
      other.is_a?(EndpointId) && other.id == id
    end
    alias eql? ==

    def hash
      id.hash
    end
  end
end
