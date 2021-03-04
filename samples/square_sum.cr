class SquareSumStore < Tasko::KVStore
  def intermediate_result(task : Tasko::Key)
    single_value("intermediate_result:#{task}", as: Int32)
  end

  def final_result
    single_value("final_result", as: Int32)
  end
end

def define_square_sum_tasks(app : Tasko::Application)
  c = SquareSumStore.new(app.engine)

  app.define_task "square_sum", ->(data : Array(Int32), context : Tasko::Context) {
    print "[#{context.current_task_key}] square_sum(#{data.inspect})..."
    result = context.create_task "square_sum_result", nil

    data.each do |num|
      elem_task = context.create_task "square_elem", num
      context.add_dependency result, requires: elem_task
    end
    puts "done"
  }

  app.define_task "square_elem", ->(data : Int32, context : Tasko::Context) {
    print "[#{context.current_task_key}] square_elem(#{data})..."
    # sleep 5
    c.intermediate_result(context.current_task_key).set(data ** 2)
    puts "done"
  }

  app.define_task "square_sum_result", ->(data : Nil, context : Tasko::Context) {
    print "[#{context.current_task_key}] square_sum_result..."
    # sleep 5
    res = 0
    context.dependencies.each do |dependency_key|
      res += c.intermediate_result(dependency_key).get
    end

    c.final_result.set(res)
    puts "done"
  }
end
