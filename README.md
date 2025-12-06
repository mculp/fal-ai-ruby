# fal-ai

[![Gem Version](https://badge.fury.io/rb/fal-ai.svg)](https://badge.fury.io/rb/fal-ai)

Ruby client for [fal.ai](https://fal.ai) - the generative AI platform with 600+ models.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "fal-ai"
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install fal-ai
```

## Usage

### Configuration

```ruby
require "fal-ai"

# Configure with API key (or set FAL_KEY environment variable)
Fal.configure do |config|
  config.api_key = "your-api-key"
  config.timeout = 300          # seconds (default: 300)
  config.poll_interval = 0.5    # seconds (default: 0.5)
end
```

### Synchronous Run

For quick operations, use `run` to execute synchronously:

```ruby
client = Fal.client

result = client.run("fal-ai/flux/dev", {
  prompt: "a beautiful sunset over mountains",
  image_size: "landscape_16_9"
})

puts result["images"].first["url"]
```

### Subscribe (Queue with Polling)

For longer operations, use `subscribe` to submit to the queue and poll until complete:

```ruby
client = Fal.client

result = client.subscribe("fal-ai/flux/dev", { prompt: "a cat" }) do |status|
  case status
  when Fal::Status::Queued
    puts "Queued at position #{status.position}"
  when Fal::Status::InProgress
    puts "Processing..."
  end
end

puts "Completed! Image: #{result['images'].first['url']}"
```

### Direct Queue Operations

For more control, use queue operations directly:

```ruby
client = Fal.client

# Submit to queue
request_id = client.queue.submit("fal-ai/flux/dev", {
  prompt: "a dog playing fetch"
})

puts "Submitted: #{request_id}"

# Poll for status
loop do
  status = client.queue.status("fal-ai/flux/dev", request_id)

  if status.completed?
    result = client.queue.result("fal-ai/flux/dev", request_id)
    puts "Done! #{result['images'].first['url']}"
    break
  end

  puts "Status: #{status.class.name}"
  sleep 1
end
```

### Error Handling

```ruby
begin
  result = client.run("fal-ai/flux/dev", { prompt: "a cat" })
rescue Fal::AuthenticationError
  puts "Check your API key"
rescue Fal::RateLimitError => e
  puts "Rate limited. Status: #{e.status_code}"
rescue Fal::ApiError => e
  puts "API error: #{e.message}"
rescue Fal::ConnectionError => e
  puts "Network issue: #{e.original_error}"
rescue Fal::TimeoutError
  puts "Request timed out"
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/mculp/fal-ai-ruby.

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).
