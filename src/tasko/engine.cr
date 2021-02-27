abstract class Tasko::Engine
  abstract def create_task_key : Key

  abstract def load_task_data(serialized, as type : Class)

  abstract def save_task_data(data : D) forall D

  abstract def submit_changeset(changeset : Changeset)

  abstract def receive_task? : Key?

  abstract def mark_as_completed(task : Key, application : Application) : Nil

  abstract def tasks_dependencies(task : Key) : Array(Key)

  abstract def execute_task(task : Key, application : Application) : Nil

  abstract def done? : Bool

  abstract def prepare(application : Application) : Nil
end
