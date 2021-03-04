require "json"

class IterateSumStore < Tasko::KVStore
  def intermediate_result(task : Tasko::Key)
    single_value("intermediate_result:#{task}", as: Int32)
  end

  def final_result
    single_value("final_result", as: Int32)
  end
end

Tasko.params SumParams, from : Int32, to : Int32
Tasko.params IterateParams, from : Int32, to : Int32, completed_task : Tasko::Key

def define_square_sum_tasks(app : Tasko::Application)
  c = IterateSumStore.new(app.engine)

  app.define_task "sum", ->(params : SumParams, context : Tasko::Context) {
    result = context.create_task "sum_completed", nil
    next_task = context.create_task "iterate", IterateParams.new(params.from, params.to, result)
    context.add_dependency result, requires: next_task
  }

  app.define_task "iterate", ->(params : IterateParams, context : Tasko::Context) {
    c.intermediate_result(context.current_task_key).set(params.from)

    if params.from < params.to
      next_task = context.create_task "iterate", IterateParams.new(params.from + 1, params.to, params.completed_task)
      context.add_dependency params.completed_task, requires: next_task
    end
  }

  app.define_task "sum_completed", ->(params : Nil, context : Tasko::Context) {
    res = 0
    context.dependencies.each do |dependency_key|
      res += c.intermediate_result(dependency_key).get
    end

    c.final_result.set(res)
  }
end
