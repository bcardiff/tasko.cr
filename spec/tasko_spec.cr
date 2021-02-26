require "./spec_helper"

describe Tasko do
  it "runs until done" do
    app = Tasko::Application.new
    intermediate_result = Hash(Tasko::Key, Int32).new
    final_result = nil

    app.define_task "square_sum", ->(data : Array(Int32), context : Tasko::Context) {
      result = context.create_task "square_sum_result", nil

      data.each do |num|
        elem_task = context.create_task "square_elem", num
        context.add_dependency result, requires: elem_task
      end
    }

    app.define_task "square_elem", ->(data : Int32, context : Tasko::Context) {
      intermediate_result[context.current_task_key] = data ** 2
    }

    app.define_task "square_sum_result", ->(data : Nil, context : Tasko::Context) {
      res = 0
      context.dependencies.each do |dependency_key|
        res += intermediate_result[dependency_key]
      end

      final_result = res
    }

    app.schedule_task "square_sum", [1, 2, 3, 4]
    app.run(exit_on_done: true)

    final_result.should eq(30)
  end
end
