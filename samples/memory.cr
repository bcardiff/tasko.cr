require "log"
require "../src/tasko"
require "./square_sum"

Log.setup_from_env

app = Tasko::Application.new(Tasko::MemoryEngine.new)
define_square_sum_tasks(app)

app.schedule_task "square_sum", [1, 2, 3, 4]

puts "Starting..."
app.run(exit_on_done: true)

pp! SquareSumStore.new(app.engine).final_result.get # => 30

puts
Tasko.generate_dot(STDOUT, app)

puts
Tasko.generate_collapsed_dot(STDOUT, app)
