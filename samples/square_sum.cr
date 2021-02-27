abstract class SquareSumContext
  property final_result : Int32?

  def set_intermediate_result(key : Tasko::Key, value : Int32)
    Mosquito::Redis.instance.set("intermediate_result:#{key.value}", value.to_s)
  end

  def get_intermediate_result(key : Tasko::Key) : Int32
    Mosquito::Redis.instance.get("intermediate_result:#{key.value}").as(String).to_i
  end
end

def define_square_sum_tasks(app : Tasko::Application, c : SquareSumContext)
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
    c.set_intermediate_result(context.current_task_key, data ** 2)
    puts "done"
  }

  app.define_task "square_sum_result", ->(data : Nil, context : Tasko::Context) {
    print "[#{context.current_task_key}] square_sum_result..."
    # sleep 5
    res = 0
    context.dependencies.each do |dependency_key|
      res += c.get_intermediate_result(dependency_key)
    end

    c.final_result = res
    puts "done"
  }
end
