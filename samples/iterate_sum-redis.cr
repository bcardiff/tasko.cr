require "log"
require "../src/tasko"
require "../src/redis"
require "./iterate_sum"

private def redis_url
  ENV["REDIS_URL"]? || "redis://localhost:6379"
end

Log.setup_from_env

redis = Redis::PooledClient.new url: redis_url
engine = Tasko::RedisEngine.new(redis)

engine.redis.flushdb # Clean up

app = Tasko::Application.new(engine)
define_square_sum_tasks(app)

app.schedule_task "sum", SumParams.new(from: 1, to: 10)

puts "Starting..."

app.run(exit_on_done: true)
pp! IterateSumStore.new(app.engine).final_result # => 30

Tasko.generate_dot(STDOUT, app)
puts

Tasko.generate_collapsed_dot(STDOUT, app)
puts
