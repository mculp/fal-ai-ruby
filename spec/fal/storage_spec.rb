# frozen_string_literal: true

require "stringio"
require "tempfile"

RSpec.describe Fal::Storage do
  let(:config) { Fal::Configuration.new.tap { |c| c.api_key = "test-key" } }
  let(:connection) { instance_double(Fal::Connection) }
  let(:storage) { described_class.new(connection: connection, config: config) }

  let(:initiate_response) do
    instance_double(
      Fal::Response,
      data: {
        "upload_url" => "https://upload.fal.example/put/abc",
        "file_url" => "https://v3.fal.media/files/abc/image.png"
      }
    )
  end

  before do
    allow(connection).to receive(:post).and_return(initiate_response)
    allow(connection).to receive(:upload)
  end

  it "returns the public file URL" do
    result = storage.upload(StringIO.new("hello"), content_type: "text/plain", file_name: "a.txt")

    expect(result).to eq("https://v3.fal.media/files/abc/image.png")
  end

  it "initiates the upload on the REST host with content type and file name" do
    expect(connection).to receive(:post) do |endpoint, body:|
      expect(endpoint).to be_a(Fal::Endpoints::StorageInitiate)
      expect(endpoint.url)
        .to eq("https://rest.fal.ai/storage/upload/initiate?storage_type=fal-cdn-v3")
      expect(body).to eq({ content_type: "image/png", file_name: "logo.png" })
    end.and_return(initiate_response)

    storage.upload(StringIO.new("x"), content_type: "image/png", file_name: "logo.png")
  end

  it "PUTs the bytes to the presigned upload URL" do
    expect(connection).to receive(:upload)
      .with("https://upload.fal.example/put/abc", body: "hello", content_type: "text/plain")

    storage.upload(StringIO.new("hello"), content_type: "text/plain", file_name: "a.txt")
  end

  it "uploads the whole IO even when the caller already consumed part of it" do
    io = StringIO.new("FULLDATA")
    io.read(4) # caller sniffed "FULL"; position now sits at "DATA"

    expect(connection).to receive(:upload)
      .with("https://upload.fal.example/put/abc", body: "FULLDATA", content_type: "text/plain")

    storage.upload(io, content_type: "text/plain", file_name: "a.txt")
  end

  it "infers content type and file name from a path" do
    Tempfile.create(["picture", ".png"]) do |file|
      file.binmode
      file.write("image-bytes")
      file.flush

      expect(connection).to receive(:post) do |_endpoint, body:|
        expect(body[:content_type]).to eq("image/png")
        expect(body[:file_name]).to eq(File.basename(file.path))
      end.and_return(initiate_response)

      storage.upload(file.path)
    end
  end

  it "falls back to application/octet-stream for unknown extensions" do
    expect(connection).to receive(:post) do |_endpoint, body:|
      expect(body[:content_type]).to eq("application/octet-stream")
    end.and_return(initiate_response)

    storage.upload(StringIO.new("data"), file_name: "mystery.xyz")
  end
end
