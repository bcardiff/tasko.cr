require "uuid"
require "json"

module Tasko::JSONTaskSerialization
  def load_task_data(serialized, as type : Class)
    type.from_json(serialized)
  end

  def save_task_data(data : D) forall D
    data.to_json
  end
end

module Tasko::UUIDTaskKeys
  def create_task_key : Key
    Key.new(value: "task:#{UUID.random}")
  end
end
