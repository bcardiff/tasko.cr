require "json"

Tasko::KVStore.define IterateSumStore do
  data intermediate_result : Int32, indexed_by: Tasko::Key
  data final_result : Int32
end

record SumParams, from : Int32, to : Int32 do
  include JSON::Serializable
end

record IterateParams, from : Int32, to : Int32, completed_task : Tasko::Key do
  include JSON::Serializable
end

def define_square_sum_tasks(app : Tasko::Application)
  c = IterateSumStore.new(app.engine)

  app.define_task "sum", ->(params : SumParams, context : Tasko::Context) {
    result = context.create_task "sum_completed", nil
    next_task = context.create_task "iterate", IterateParams.new(params.from, params.to, result)
    context.add_dependency result, requires: next_task
  }

  app.define_task "iterate", ->(params : IterateParams, context : Tasko::Context) {
    c.intermediate_result[context.current_task_key] = params.from

    if params.from < params.to
      next_task = context.create_task "iterate", IterateParams.new(params.from + 1, params.to, params.completed_task)
      context.add_dependency params.completed_task, requires: next_task
    end
  }

  app.define_task "sum_completed", ->(params : Nil, context : Tasko::Context) {
    res = 0
    context.dependencies.each do |dependency_key|
      res += c.intermediate_result[dependency_key]
    end

    c.final_result = res
  }
end
