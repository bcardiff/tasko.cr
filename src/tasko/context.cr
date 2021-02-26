class Tasko::Context
  def initialize(@changeset : Changeset, @current_task_key : Key, @dependencies : Array(Key))
  end

  def create_task(name : String, data : D) : Key forall D
    @changeset.create_task(name, data)
  end

  def add_dependency(task : Key, *, requires : Key) : Nil
    @changeset.add_dependency(task, requires: requires)
  end

  def current_task_key : Key
    @current_task_key
  end

  def dependencies : Array(Key)
    @dependencies
  end
end
