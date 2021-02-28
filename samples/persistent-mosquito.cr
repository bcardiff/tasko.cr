require "log"
require "../src/tasko"
require "../src/mosquito"
require "./square_sum"

Log.setup_from_env

class SquareSumMosquitoContext < SquareSumContext
  def set_intermediate_result(key : Tasko::Key, value : Int32)
    Mosquito::Redis.instance.set("intermediate_result:#{key.value}", value.to_s)
  end

  def get_intermediate_result(key : Tasko::Key) : Int32
    Mosquito::Redis.instance.get("intermediate_result:#{key.value}").as(String).to_i
  end
end

engine = Tasko::MosquitoEngine.new

engine.redis.flushdb # Clean up

app = Tasko::Application.new(engine)
context = SquareSumMosquitoContext.new
define_square_sum_tasks(app, context)

app.schedule_task "square_sum", [1, 2, 3, 4]

puts "Starting..."
app.run(exit_on_done: true)
pp! context.final_result # => 30
