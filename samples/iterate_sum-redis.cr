require "log"
require "../src/tasko"
require "../src/redis"
require "./iterate_sum"

private def redis_url
  ENV["REDIS_URL"]? || "redis://localhost:6379"
end

Log.setup_from_env

class IterateSumRedisContext < IterateSumContext
  def initialize(@redis : Redis::PooledClient)
  end

  def set_intermediate_result(key : Tasko::Key, value : Int32)
    @redis.set("intermediate_result:#{key.value}", value.to_s)
  end

  def get_intermediate_result(key : Tasko::Key) : Int32
    @redis.get("intermediate_result:#{key.value}").as(String).to_i
  end
end

redis = Redis::PooledClient.new url: redis_url
engine = Tasko::RedisEngine.new(redis)

engine.redis.flushdb # Clean up

app = Tasko::Application.new(engine)
context = IterateSumRedisContext.new(redis)
define_square_sum_tasks(app, context)

app.schedule_task "sum", SumParams.new(from: 1, to: 10)

puts "Starting..."

app.run(exit_on_done: true)
pp! context.final_result # => 30

Tasko.generate_dot(STDOUT, app)
puts
