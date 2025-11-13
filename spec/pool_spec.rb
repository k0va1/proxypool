# frozen_string_literal: true

require "json"

RSpec.describe Proxypool::Pool do
  let(:sample_proxies) do
    [
      "http://192.168.1.1:8080",
      "https://10.0.0.1:3128",
      "socks5://user:pass@proxy.example.com:1080"
    ]
  end

  describe "#initialize" do
    it "initializes with default values" do
      pool = described_class.new
      expect(pool.size).to eq(0)
      expect(pool).to be_empty
    end

    it "initializes with proxies" do
      pool = described_class.new(proxies: sample_proxies)
      expect(pool.size).to eq(3)
      expect(pool).not_to be_empty
    end

    it "validates load_factor parameter" do
      expect { described_class.new(load_factor: -0.1) }
        .to raise_error(Proxypool::Error, /load_factor must be a number between 0 and 1/)
      expect { described_class.new(load_factor: 1.1) }
        .to raise_error(Proxypool::Error, /load_factor must be a number between 0 and 1/)
    end

    it "validates refresh_interval parameter" do
      expect { described_class.new(refresh_interval: -1) }
        .to raise_error(Proxypool::Error, /refresh_interval must be a positive number/)
    end

    it "validates usage_threshold parameter" do
      expect { described_class.new(usage_threshold: -1) }
        .to raise_error(Proxypool::Error, /usage_threshold must be a non-negative number/)
    end
  end

  describe "#next_proxy" do
    let(:pool) { described_class.new(proxies: sample_proxies) }

    it "returns a proxy when available" do
      proxy = pool.next_proxy
      expect(proxy).to be_a(Proxypool::Proxy)
      expect(proxy.valid).to be true
    end

    it "returns nil when no proxies are available" do
      empty_pool = described_class.new
      expect(empty_pool.next_proxy).to be_nil
    end

    it "updates proxy usage when returned" do
      # Get the proxy that will be used
      returned_proxy = pool.next_proxy
      expect(returned_proxy.usage_count).to eq(1)
      expect(returned_proxy.last_used_at).not_to be_nil
    end

    it "respects usage threshold" do
      pool = described_class.new(proxies: sample_proxies, usage_threshold: 3600) # 1 hour

      # Use all proxies
      3.times { pool.next_proxy }

      # All should be recently used, so next_proxy should return the least recently used
      proxy = pool.next_proxy
      expect(proxy).not_to be_nil
    end

    it "returns nil when all proxies are invalid" do
      # Use a high load_factor to prevent automatic refresh when all proxies are invalid
      pool = described_class.new(proxies: sample_proxies, load_factor: 1.0)

      # Mark all proxies as invalid
      pool.proxies.keys.each { |key| pool.mark_invalid!(key) }

      expect(pool.next_proxy).to be_nil
    end
  end

  describe "#mark_invalid!" do
    let(:pool) { described_class.new(proxies: sample_proxies) }

    it "marks a proxy as invalid by string key" do
      proxy_key = sample_proxies.first
      expect(pool.mark_invalid!(proxy_key)).to be true

      proxy = pool.proxies[proxy_key]
      expect(proxy.valid).to be false
      expect(proxy.last_used_at).not_to be_nil
    end

    it "marks a proxy as invalid by Proxy object" do
      proxy_obj = pool.proxies.values.first
      expect(pool.mark_invalid!(proxy_obj)).to be true

      # Find the proxy by reconstructed key
      proxy_key = "#{proxy_obj.protocol}://#{proxy_obj.ip}:#{proxy_obj.port}"
      updated_proxy = pool.proxies[proxy_key]
      expect(updated_proxy.valid).to be false
    end

    it "raises error for non-existent proxy" do
      expect { pool.mark_invalid!("http://nonexistent:8080") }
        .to raise_error(Proxypool::Error, /not found in the pool/)
    end
  end

  describe "#stats" do
    let(:pool) { described_class.new(proxies: sample_proxies) }

    it "returns correct statistics" do
      stats = pool.stats

      expect(stats[:total]).to eq(3)
      expect(stats[:valid]).to eq(3)
      expect(stats[:invalid]).to eq(0)
      expect(stats[:last_updated]).to be_a(Time)
    end

    it "updates stats after marking proxies invalid" do
      pool.mark_invalid!(sample_proxies.first)
      stats = pool.stats

      expect(stats[:total]).to eq(3)
      expect(stats[:valid]).to eq(2)
      expect(stats[:invalid]).to eq(1)
    end
  end

  describe "#refresh_proxies!" do
    it "refreshes proxies with new data" do
      pool = described_class.new(proxies: sample_proxies)
      original_time = pool.stats[:last_updated]

      sleep(0.01) # Ensure time difference
      pool.refresh_proxies!

      expect(pool.stats[:last_updated]).to be > original_time
    end

    it "works with callable proxies source" do
      proxy_source = -> { sample_proxies }
      pool = described_class.new(proxies: proxy_source)

      expect(pool.size).to eq(3)
      pool.refresh_proxies!
      expect(pool.size).to eq(3)
    end
  end

  describe "proc-based proxy loading" do
    it "initializes with a proc that returns proxy list" do
      proxy_loader = -> { sample_proxies }
      pool = described_class.new(proxies: proxy_loader)

      expect(pool.size).to eq(3)
      expect(pool.valid_count).to eq(3)
    end

    it "calls the proc each time proxies are refreshed" do
      call_count = 0
      dynamic_proxies = -> {
        call_count += 1
        case call_count
        when 1
          ["http://first.proxy:8080"]
        when 2
          ["http://second.proxy:8080", "https://third.proxy:3128"]
        else
          sample_proxies
        end
      }

      pool = described_class.new(proxies: dynamic_proxies)
      expect(pool.size).to eq(1) # First call
      expect(call_count).to eq(1)

      pool.refresh_proxies!
      expect(pool.size).to eq(2) # Second call
      expect(call_count).to eq(2)

      pool.refresh_proxies!
      expect(pool.size).to eq(3) # Third call
      expect(call_count).to eq(3)
    end

    it "handles proc that returns empty array" do
      empty_loader = -> { [] }
      pool = described_class.new(proxies: empty_loader)

      expect(pool.size).to eq(0)
      expect(pool).to be_empty
      expect(pool.next_proxy).to be_nil
    end

    it "handles proc that returns nil" do
      nil_loader = -> {}
      pool = described_class.new(proxies: nil_loader)

      expect(pool.size).to eq(0)
      expect(pool).to be_empty
    end
  end

  describe "proxy parsing" do
    it "parses simple HTTP proxy" do
      pool = described_class.new(proxies: ["http://1.2.3.4:8080"])
      proxy = pool.proxies.values.first

      expect(proxy.protocol).to eq("http")
      expect(proxy.ip).to eq("1.2.3.4")
      expect(proxy.port).to eq(8080)
      expect(proxy.username).to be_nil
      expect(proxy.password).to be_nil
    end

    it "parses proxy with authentication" do
      pool = described_class.new(proxies: ["http://user:pass@proxy.example.com:8080"])
      proxy = pool.proxies.values.first

      expect(proxy.protocol).to eq("http")
      expect(proxy.ip).to eq("proxy.example.com")
      expect(proxy.port).to eq(8080)
      expect(proxy.username).to eq("user")
      expect(proxy.password).to eq("pass")
    end

    it "skips invalid proxy formats" do
      invalid_proxies = [
        "not-a-proxy",
        "http://",
        "http://host",
        "http://host:99999", # Invalid port
        nil,
        123
      ]

      pool = described_class.new(proxies: invalid_proxies + sample_proxies)
      expect(pool.size).to eq(3) # Only valid proxies from sample_proxies
    end

    it "normalizes protocol to lowercase" do
      pool = described_class.new(proxies: ["HTTP://1.2.3.4:8080"])
      proxy = pool.proxies.values.first

      expect(proxy.protocol).to eq("http")
    end
  end
end
