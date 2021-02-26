class Tasko::Changeset
  def initialize(@application : Application)
  end

  record CreateTask, key : Key, name : String, serialized_data : String
  record AddDependency, task : Key, requires : Key

  # :nodoc:
  property created_tasks = [] of CreateTask
  # :nodoc:
  property created_dependencies = [] of AddDependency

  def create_task(name : String, data : D) : Key forall D
    new_task = CreateTask.new(
      key: @application.engine.create_task_key,
      name: name,
      serialized_data: @application.engine.save_task_data(data)
    )

    @created_tasks << new_task

    new_task.key
  end

  def add_dependency(task : Key, *, requires : Key) : Nil
    @created_dependencies << AddDependency.new(task: task, requires: requires)
  end
end
