require "log"
require "../src/tasko"
require "../src/mosquito"
require "./square_sum"

Log.setup_from_env

class SquareSumMemoryContext < SquareSumContext
  @intermediate_result = Hash(Tasko::Key, Int32).new

  def set_intermediate_result(key : Tasko::Key, value : Int32)
    @intermediate_result[key] = value
  end

  def get_intermediate_result(key : Tasko::Key) : Int32
    @intermediate_result[key]
  end
end

app = Tasko::Application.new(Tasko::MemoryEngine.new)
context = SquareSumMemoryContext.new
define_square_sum_tasks(app, context)

app.schedule_task "square_sum", [1, 2, 3, 4]

puts "Starting..."
app.run(exit_on_done: true)

pp! context.final_result # => 30

puts

Tasko.generate_dot(STDOUT, app)
