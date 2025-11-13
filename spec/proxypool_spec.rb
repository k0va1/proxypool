# frozen_string_literal: true

RSpec.describe Proxypool do
  after(:each) do
    Proxypool.clear_pools
  end

  it "has a version number" do
    expect(Proxypool::VERSION).not_to be nil
  end

  describe ".create" do
    it "creates a new pool with the given name" do
      pool = Proxypool.create(name: :test)
      expect(pool).to be_a(Proxypool::Pool)
      expect(Proxypool.pool_exists?(:test)).to be true
    end

    it "accepts options for the pool" do
      proxies = ["http://1.2.3.4:8080", "https://5.6.7.8:3128"]
      pool = Proxypool.create(name: :test, proxies: proxies, load_factor: 0.5)
      expect(pool.size).to eq(2)
    end

    it "raises an error when name is nil" do
      expect { Proxypool.create(name: nil) }.to raise_error(ArgumentError)
    end
  end

  describe ".[]" do
    it "retrieves an existing pool" do
      original_pool = Proxypool.create(name: :test)
      retrieved_pool = Proxypool[:test]
      expect(retrieved_pool).to eq(original_pool)
    end

    it "returns nil when pool doesn't exist" do
      expect(Proxypool[:nonexistent]).to be_nil
    end
  end

  describe ".pools" do
    it "returns list of pool names" do
      Proxypool.create(name: :pool1)
      Proxypool.create(name: :pool2)
      expect(Proxypool.pools).to contain_exactly(:pool1, :pool2)
    end
  end

  describe ".pool_exists?" do
    it "returns true for existing pools" do
      Proxypool.create(name: :test)
      expect(Proxypool.pool_exists?(:test)).to be true
    end

    it "returns false for non-existing pools" do
      expect(Proxypool.pool_exists?(:nonexistent)).to be false
    end
  end

  describe ".remove_pool" do
    it "removes the specified pool" do
      Proxypool.create(name: :test)
      expect(Proxypool.pool_exists?(:test)).to be true

      Proxypool.remove_pool(:test)
      expect(Proxypool.pool_exists?(:test)).to be false
    end
  end
end
