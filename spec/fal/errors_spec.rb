# frozen_string_literal: true

RSpec.describe Fal::Error do
  it "inherits from StandardError" do
    expect(Fal::Error.superclass).to eq(StandardError)
  end
end

RSpec.describe Fal::ConfigurationError do
  it "inherits from Fal::Error" do
    expect(Fal::ConfigurationError.superclass).to eq(Fal::Error)
  end
end

RSpec.describe Fal::ConnectionError do
  it "inherits from Fal::Error" do
    expect(Fal::ConnectionError.superclass).to eq(Fal::Error)
  end

  describe "#original_error" do
    it "stores the original error" do
      original = StandardError.new("network failure")
      error = Fal::ConnectionError.new("Connection failed", original_error: original)

      expect(error.original_error).to eq(original)
    end

    it "defaults to nil" do
      error = Fal::ConnectionError.new("Connection failed")

      expect(error.original_error).to be_nil
    end
  end

  describe "#message" do
    it "returns the error message" do
      error = Fal::ConnectionError.new("Connection failed")

      expect(error.message).to eq("Connection failed")
    end
  end
end

RSpec.describe Fal::ApiError do
  it "inherits from Fal::Error" do
    expect(Fal::ApiError.superclass).to eq(Fal::Error)
  end

  describe "#status_code" do
    it "stores the HTTP status code" do
      error = Fal::ApiError.new("Bad request", status_code: 400)

      expect(error.status_code).to eq(400)
    end
  end

  describe "#response_body" do
    it "stores the response body" do
      body = { "detail" => "Invalid input" }
      error = Fal::ApiError.new("Bad request", status_code: 400, response_body: body)

      expect(error.response_body).to eq(body)
    end

    it "defaults to nil" do
      error = Fal::ApiError.new("Bad request", status_code: 400)

      expect(error.response_body).to be_nil
    end
  end
end

RSpec.describe Fal::AuthenticationError do
  it "inherits from Fal::ApiError" do
    expect(Fal::AuthenticationError.superclass).to eq(Fal::ApiError)
  end
end

RSpec.describe Fal::NotFoundError do
  it "inherits from Fal::ApiError" do
    expect(Fal::NotFoundError.superclass).to eq(Fal::ApiError)
  end
end

RSpec.describe Fal::RateLimitError do
  it "inherits from Fal::ApiError" do
    expect(Fal::RateLimitError.superclass).to eq(Fal::ApiError)
  end
end

RSpec.describe Fal::ServerError do
  it "inherits from Fal::ApiError" do
    expect(Fal::ServerError.superclass).to eq(Fal::ApiError)
  end
end

RSpec.describe Fal::TimeoutError do
  it "inherits from Fal::Error" do
    expect(Fal::TimeoutError.superclass).to eq(Fal::Error)
  end
end
