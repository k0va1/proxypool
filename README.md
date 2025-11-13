# Proxypool

A Ruby library for intelligent proxy pool management with automatic rotation, health checking, and dynamic loading from external sources.

## Features

- **Smart proxy rotation** with usage tracking and cooldown periods
- **Automatic health management** with invalid proxy detection
- **Dynamic proxy loading** from external sources (APIs, databases, files)
- **Multiple proxy formats** supported (HTTP, HTTPS, SOCKS5) with authentication
- **Configurable refresh strategies** based on time intervals and failure rates
- **Comprehensive statistics** and monitoring capabilities

## Installation

```ruby
# Gemfile
gem "proxypool"
```

Or install directly:
```bash
gem install proxypool
```

## Basic Usage

### Static Proxy List

```ruby
require "proxypool"

proxies = [
  "http://192.168.1.1:8080",
  "https://10.0.0.1:3128",
  "socks5://user:pass@proxy.example.com:1080"
]

# Create a named pool
pool = Proxypool.create(name: :my_pool, proxies: proxies)

# Get the next available proxy
proxy = pool.next_proxy
# => #<data Proxypool::Proxy protocol="http", ip="192.168.1.1", port=8080, ...>

# Access proxy details
puts proxy.protocol  # => "http"
puts proxy.ip        # => "192.168.1.1"
puts proxy.port      # => 8080
puts proxy.username  # => nil (or actual username if provided)

# Get pool statistics
stats = pool.stats
# => {total: 3, valid: 3, invalid: 0, last_updated: 2023-...}
```

### Dynamic Proxy Loading from External Sources

Load proxies dynamically from APIs, databases, or other external sources:

```ruby
require "proxypool"
require "faraday"
require "json"

# Define a proc that fetches proxies from an external API
proxies = proc do
  response = Faraday.get("https://api.example.com/proxies.json")
  JSON.parse(response.body).map { |item| item["proxy"] }
  # => ["socks5://23.45.67:8901", "socks5://98.76.54:3210", ...]
end

# Create pool with dynamic loading
pool = Proxypool.create(name: :dynamic_pool, proxies: proxies)

# Use proxies normally
proxy = pool.next_proxy
puts "#{proxy.protocol}://#{proxy.ip}:#{proxy.port}"

# Refresh proxies from the source (calls the proc again)
pool.refresh_proxies!
```

## Advanced Configuration

### Pool Options

```ruby
pool = Proxypool.create(
  name: :advanced_pool,
  proxies: proxy_list,
  load_factor: 0.8,        # Refresh when 80% of proxies are invalid
  refresh_interval: 300,    # Refresh every 5 minutes
  usage_threshold: 60       # Wait 60 seconds before reusing a proxy
)
```

### Pool Management

```ruby
# Check if pool exists
Proxypool.pool_exists?(:my_pool)  # => true

# List all pool names
Proxypool.pools  # => [:my_pool, :dynamic_pool, :advanced_pool]

# Retrieve existing pool
pool = Proxypool[:my_pool]  # => Pool instance or nil

# Remove pool
Proxypool.remove_pool(:my_pool)

# Clear all pools
Proxypool.clear_pools
```

### Proxy Health Management

```ruby
# Mark a proxy as invalid (removes from rotation)
pool.mark_invalid!(proxy)
# or by string
pool.mark_invalid!("http://bad.proxy:8080")

# Check pool health
puts pool.size          # Total proxies
puts pool.valid_count   # Valid proxies
puts pool.invalid_count # Invalid proxies
puts pool.empty?        # No proxies available
```

## Proxy Format Support

The library supports various proxy formats with automatic parsing:

```ruby
proxies = [
  "http://1.2.3.4:8080",                    # Basic HTTP
  "https://secure.proxy:3128",              # HTTPS
  "socks5://fast.proxy:1080",               # SOCKS5
  "http://user:pass@auth.proxy:8080",       # With authentication
  "socks5://user:pass@secure.proxy:1080"    # SOCKS5 with auth
]
```

## Dynamic Loading Examples

### Database Integration

```ruby
# Load from database
database_loader = proc do
  # Your database query logic
  ProxyRecord.where(active: true).pluck(:url)
end

pool = Proxypool.create(name: :db_pool, proxies: database_loader)
```

### File-based Configuration

```ruby
# Load from configuration file
file_loader = proc do
  YAML.load_file('config/proxies.yml')['proxies']
end

pool = Proxypool.create(name: :file_pool, proxies: file_loader)
```

### Multiple Source Rotation

```ruby
# Rotate between different proxy sources
sources = [
  -> { api_source_1.fetch_proxies },
  -> { api_source_2.fetch_proxies },
  -> { fallback_source.fetch_proxies }
]

current_source = 0
rotating_loader = proc do
  result = sources[current_source].call
  current_source = (current_source + 1) % sources.length
  result
end

pool = Proxypool.create(name: :rotating_pool, proxies: rotating_loader)
```

## Error Handling

The library handles errors gracefully:

- Invalid proxy formats are automatically skipped with warnings
- Failed callable sources return empty arrays and log warnings
- Network errors during refresh don't crash the pool
- Comprehensive input validation with meaningful error messages

## Thread Safety

Each pool manages its own state and can be safely used across multiple threads. However, if you need to share pools between threads, consider using appropriate synchronization mechanisms for your use case.



## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/proxypool.
