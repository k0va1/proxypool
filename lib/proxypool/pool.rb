require "time"

module Proxypool
  class Pool
    LOAD_FACTOR = 0.8
    REFRESH_INTERVAL = 600 # seconds
    USAGE_THRESHOLD = 60 # seconds

    def initialize(proxies: [], load_factor: LOAD_FACTOR, refresh_interval: REFRESH_INTERVAL, usage_threshold: USAGE_THRESHOLD)
      validate_options!(load_factor, refresh_interval, usage_threshold)

      @usage_threshold = usage_threshold
      @load_factor = load_factor
      @refresh_interval = refresh_interval
      @initial_proxies = proxies
      @last_updated_at = Time.now

      # Initialize proxies immediately
      proxy_data = fetch_proxies(proxies)
      @proxies = assign_proxies!(proxy_data)
    end

    def next_proxy
      refresh_if_needed!

      return nil if proxies.empty?

      # Find all available proxies (valid and not recently used)
      available_proxies = proxies.select do |key, proxy|
        proxy.valid && (proxy.last_used_at.nil? || Time.now - proxy.last_used_at > @usage_threshold)
      end

      # If no available proxies, return the least recently used valid proxy
      if available_proxies.empty?
        valid_proxies = proxies.select { |_, proxy| proxy.valid }
        return nil if valid_proxies.empty?

        proxy_key = valid_proxies.min_by { |_, proxy| proxy.last_used_at || Time.at(0) }.first
      else
        proxy_key = available_proxies.keys.sample
      end

      proxy = proxies[proxy_key]

      # Update proxy usage
      updated_proxy = Proxypool::Proxy.new(
        protocol: proxy.protocol,
        ip: proxy.ip,
        port: proxy.port,
        valid: proxy.valid,
        username: proxy.username,
        password: proxy.password,
        last_used_at: Time.now,
        usage_count: proxy.usage_count + 1
      )
      proxies[proxy_key] = updated_proxy

      updated_proxy
    end

    def proxies
      @proxies ||= {}
    end

    def refresh_proxies!
      new_proxies = fetch_proxies(@initial_proxies)
      @proxies = assign_proxies!(new_proxies)
      @last_updated_at = Time.now
    end

    def size
      @proxies&.size || 0
    end

    def valid_count
      @proxies&.count { |_, proxy| proxy.valid } || 0
    end

    def invalid_count
      size - valid_count
    end

    def empty?
      size == 0
    end

    def stats
      {
        total: size,
        valid: valid_count,
        invalid: invalid_count,
        last_updated: @last_updated_at
      }
    end

    def mark_invalid!(proxy)
      proxy_key = case proxy
      when String then proxy
      when Proxypool::Proxy then "#{proxy.protocol}://#{proxy.ip}:#{proxy.port}"
      else proxy.to_s
      end

      if @proxies&.key?(proxy_key)
        @proxies[proxy_key] = @proxies[proxy_key].with(valid: false, last_used_at: Time.now)
        true
      else
        raise Proxypool::Error, "Proxy #{proxy_key} not found in the pool"
      end
    end

    private

    def validate_options!(load_factor, refresh_interval, usage_threshold)
      unless load_factor.is_a?(Numeric) && load_factor.between?(0, 1)
        raise Proxypool::Error, "load_factor must be a number between 0 and 1"
      end

      unless refresh_interval.is_a?(Numeric) && refresh_interval.positive?
        raise Proxypool::Error, "refresh_interval must be a positive number"
      end

      unless usage_threshold.is_a?(Numeric) && usage_threshold >= 0
        raise Proxypool::Error, "usage_threshold must be a non-negative number"
      end
    end

    def assign_proxies!(proxies)
      return {} if proxies.nil? || proxies.empty?

      @proxies = proxies.each_with_object({}) do |proxy, hash|
        next unless proxy.is_a?(String) && proxy.include?("://")

        begin
          protocol, rest = proxy.split("://", 2)
          next if rest.nil? || rest.empty?

          # Handle authentication in URL: user:pass@host:port
          if rest.include?("@")
            auth_part, host_part = rest.split("@", 2)
            username, password = auth_part.split(":", 2) if auth_part.include?(":")
            rest = host_part
          end

          parts = rest.split(":")
          next if parts.length < 2

          ip = parts[0]
          port = parts[1].to_i
          next if port <= 0 || port > 65535

          hash[proxy] = Proxypool::Proxy.new(
            protocol: protocol.downcase,
            ip: ip,
            port: port,
            username: username,
            password: password,
            last_used_at: nil,
            usage_count: 0,
            valid: true
          )
        rescue => e
          warn "Skipping invalid proxy '#{proxy}': #{e.message}"
        end
      end
    end

    def refresh_if_needed!
      refresh_by_interval!
      refresh_by_usage!
    end

    def refresh_by_interval!
      return unless @last_updated_at

      if Time.now - @last_updated_at > @refresh_interval
        refresh_proxies!
        @last_updated_at = Time.now
      end
    end

    def refresh_by_usage!
      return if @proxies.nil? || @proxies.empty?

      total_proxies = @proxies.size
      invalid_proxies = @proxies.values.count { |proxy| !proxy.valid }
      invalid_ratio = invalid_proxies.to_f / total_proxies

      refresh_proxies! if invalid_ratio > @load_factor
    end

    def fetch_proxies(proxies)
      if proxies.respond_to?(:call)
        proxies.call
      else
        proxies
      end
    end
  end
end
