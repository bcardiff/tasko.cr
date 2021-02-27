require "json"
require "uuid"

class Tasko::MemoryEngine < Tasko::Engine
  enum State
    Pending
    Ready
    Running
    Completed
  end

  class MemoryTask
    getter descriptor : TaskDescriptor
    getter dependencies : Array(Key)
    property state : State

    def initialize(@descriptor : TaskDescriptor)
      @dependencies = Array(Key).new
      @state = State::Pending
    end
  end

  def initialize
    @tasks = Hash(Key, MemoryTask).new
  end

  def create_task_key : Key
    Key.new(value: "task:#{UUID.random}")
  end

  def load_task_data(serialized, as type : Class)
    type.from_json(serialized)
  end

  def save_task_data(data : D) forall D
    data.to_json
  end

  def submit_changeset(changeset : Changeset)
    # TODO lock for MT

    changeset.created_tasks.each do |change|
      # TODO check that task are not overwritten
      @tasks[change.key] = MemoryTask.new(TaskDescriptor.new(key: change.key, name: change.name, serialized_data: change.serialized_data))
    end

    # TODO check all tasks exists
    # TODO check no loops are created
    changeset.created_dependencies.each do |change|
      @tasks[change.task].dependencies << change.requires
    end

    check_ready_tasks
  end

  def receive_task? : Key?
    check_ready_tasks

    # TODO lock for MT or channels
    @tasks.each_value do |t|
      if t.state == State::Ready
        t.state = State::Running
        return t.descriptor.key
      end
    end

    nil
  end

  def execute_task(task : Key, application : Application) : Nil
    application.execute_task(@tasks[task].descriptor)
  end

  def mark_as_completed(task : Key, application : Application) : Nil
    t = @tasks[task]
    raise "Task is not running" unless t.state == State::Running
    t.state = State::Completed
  end

  def tasks_dependencies(task : Key) : Array(Key)
    @tasks[task].dependencies.dup
  end

  def done? : Bool
    @tasks.values.all? { |t| t.state == State::Completed }
  end

  def prepare(application : Application) : Nil
  end

  protected def check_ready_tasks
    # TODO lock for MT or channels
    @tasks.each_value do |t|
      next unless t.state == State::Pending

      if t.dependencies.all? { |d| @tasks[d].state == State::Completed }
        t.state = State::Ready
      end
    end
  end
end
