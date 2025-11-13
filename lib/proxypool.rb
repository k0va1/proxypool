require "zeitwerk"
loader = Zeitwerk::Loader.for_gem
loader.setup

module Proxypool
  class Error < StandardError; end

  Proxy = Data.define(:protocol, :ip, :port, :valid, :last_used_at, :usage_count, :username, :password)

  @@pools = {}

  def self.create(name:, **options)
    raise ArgumentError, "Pool name cannot be nil" if name.nil?

    @@pools[name] = Pool.new(**options)
  end

  def self.[](name)
    @@pools[name]
  end

  def self.pools
    @@pools.keys
  end

  def self.pool_exists?(name)
    @@pools.key?(name)
  end

  def self.remove_pool(name)
    @@pools.delete(name)
  end

  def self.clear_pools
    @@pools.clear
  end
end
