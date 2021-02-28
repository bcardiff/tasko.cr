require "log"
require "../src/tasko"
require "../src/redis"
require "./square_sum"

private def redis_url
  ENV["REDIS_URL"]? || "redis://localhost:6379"
end

Log.setup_from_env

redis = Redis::PooledClient.new url: redis_url
engine = Tasko::RedisEngine.new(redis)

engine.redis.flushdb # Clean up

app = Tasko::Application.new(engine)
define_square_sum_tasks(app)

app.schedule_task "square_sum", [1, 2, 3, 4]

puts "Starting..."
Tasko.generate_dot(STDOUT, app)
puts

app.run(exit_on_done: true)

pp! SquareSumStore.new(app.engine).final_result # => 30
