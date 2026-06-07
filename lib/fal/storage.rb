# frozen_string_literal: true

module Fal
  # Uploads files to fal storage (the fal CDN) and returns their public URLs,
  # which you then pass to models as image/video/audio inputs.
  #
  # The upload is two steps: initiate (a fal REST call that returns a presigned
  # upload URL plus the eventual file URL), then PUT the bytes to that URL.
  class Storage
    def initialize(connection:, config:)
      @connection = connection
      @config = config
    end

    # Accepts a file path (String/Pathname) or any IO that responds to #read.
    # Returns the public URL of the uploaded file.
    def upload(file, content_type: nil, file_name: nil)
      source = Source.for(file, content_type: content_type, file_name: file_name)
      ticket = initiate(source)
      @connection.upload(
        ticket.fetch("upload_url"), body: source.bytes, content_type: source.content_type
      )
      ticket.fetch("file_url")
    end

    private

    def initiate(source)
      endpoint = Endpoints::StorageInitiate.new(base_url: @config.rest_url)
      @connection.post(
        endpoint, body: { content_type: source.content_type, file_name: source.file_name }
      ).data
    end

    # Normalizes an upload input into bytes, a file name, and a content type
    # (inferred from the file extension when not given).
    class Source
      CONTENT_TYPES = {
        ".png" => "image/png", ".jpg" => "image/jpeg", ".jpeg" => "image/jpeg",
        ".gif" => "image/gif", ".webp" => "image/webp", ".bmp" => "image/bmp",
        ".mp4" => "video/mp4", ".webm" => "video/webm", ".mov" => "video/quicktime",
        ".mp3" => "audio/mpeg", ".wav" => "audio/wav", ".ogg" => "audio/ogg",
        ".json" => "application/json", ".txt" => "text/plain", ".pdf" => "application/pdf"
      }.freeze
      DEFAULT_CONTENT_TYPE = "application/octet-stream"

      def self.for(file, content_type:, file_name:)
        if file.respond_to?(:read)
          new(bytes: file.read, file_name: file_name || "upload", content_type: content_type)
        else
          path = file.to_s
          new(
            bytes: File.binread(path),
            file_name: file_name || File.basename(path),
            content_type: content_type
          )
        end
      end

      def initialize(bytes:, file_name:, content_type:)
        @bytes = bytes
        @file_name = file_name
        @content_type = content_type || infer_content_type
      end

      attr_reader :bytes, :file_name, :content_type

      private

      def infer_content_type
        CONTENT_TYPES.fetch(File.extname(@file_name).downcase, DEFAULT_CONTENT_TYPE)
      end
    end
  end
end
