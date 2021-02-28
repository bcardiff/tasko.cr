require "uuid"
require "json"

module Tasko::JSONTaskSerialization
  def load_task_data(serialized : String, as type : Class)
    type.from_json(serialized)
  end

  def save_task_data(data : D) : String forall D
    data.to_json
  end
end

module Tasko::UUIDTaskKeys
  def create_task_key : Key
    Key.new(value: "task:#{UUID.random}")
  end
end

module Tasko::NaivePollingScheduler
  abstract def receive_task? : Key?

  abstract def execute_task(task : Key) : Nil

  abstract def done? : Bool

  abstract def prepare(application : Application) : Nil

  def run(application : Application, exit_on_done : Bool) : Nil
    prepare(application)

    if exit_on_done
      while !done?
        while (task = receive_task?)
          execute_task(task)
        end

        sleep 1
        Fiber.yield
      end

      # TODO should wait for all current tasks to finish
    end
  end
end
