abstract class Tasko::Engine
  abstract def create_task_key : Key

  abstract def deserialize_data(serialized : String, as type : Class)

  abstract def serialize_data(data : D) : String forall D

  abstract def submit_changeset(changeset : Changeset, current_task_key : Key?)

  abstract def mark_as_completed(task : Key) : Nil

  abstract def tasks_dependencies(task : Key) : Array(Key)

  abstract def run(application : Application, exit_on_done : Bool) : Nil

  # Optional
  def stats : Array(TaskStats)
    raise "Not Supported"
  end

  def store : KVStore
    raise "Not Supported"
  end
end
