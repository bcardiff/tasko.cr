require "spec"
require "../src/tasko"
require "../src/redis"

def with_redis
  redis_url = ENV["REDIS_URL"]? || "redis://localhost:6379"
  redis = Redis::PooledClient.new url: redis_url
  redis.flushdb # Clean up
  yield redis
end
