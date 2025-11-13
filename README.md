# Proxypool

## Usage

```ruby
# Gemfile
gem "proxypool"
```


```ruby
require "proxypool"

proxies = [
"socks5://123.45.67:1233",
"socks5://98.76.54:3210",
"socks5://11.22.33:4455"
]

pool = Proxypool.create(proxies: proxies)
pool.next_proxy # => "socks5://98.76.54:3210"
pool.next_proxy # => "socks5://11.22.33:4455"


```

Using with a block:

```ruby
require "proxypool"
require "faraday"
require "json"

proxies = proc do
  proxy_response = Faraday.get("https://raw.githubusercontent.com/proxifly/free-proxy-list/refs/heads/main/proxies/protocols/socks5/data.json")
  JSON.parse(proxy_response.body).pluck("proxy") #=> ["socks5://23.45.67:8901", "socks5://98.76.54:3210", ...]
end

pool = Proxypool.create(proxies: proxies)
pool.next_proxy # => "socks5://23.45.67:8901"

pool.refresh_proxies! # Refresh the proxy list from the proc
```



## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/proxypool.
