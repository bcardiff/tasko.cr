require "./helpers"

class Tasko::MemoryEngine < Tasko::Engine
  include JSONTaskSerialization
  include UUIDTaskKeys
  include NaivePollingScheduler

  enum State
    Pending
    Ready
    Running
    Completed
  end

  class MemoryTask
    getter descriptor : TaskDescriptor
    getter dependencies : Array(Key)
    getter initiated_by : Key?
    property state : State

    def initialize(@descriptor : TaskDescriptor, @initiated_by : Key?)
      @dependencies = Array(Key).new
      @state = State::Pending
    end
  end

  def initialize
    @tasks = Hash(Key, MemoryTask).new
    @store = ::Tasko::MemoryEngine::KVStore.new(self)
  end

  getter! application : Application
  getter! store : ::Tasko::KVStore

  def submit_changeset(changeset : Changeset, current_task_key : Key?)
    # TODO lock for MT

    changeset.created_tasks.each do |change|
      # TODO check that task are not overwritten
      @tasks[change.key] = MemoryTask.new(
        TaskDescriptor.new(
          key: change.key,
          name: change.name,
          serialized_data: change.serialized_data,
        ),
        initiated_by: current_task_key
      )
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

  def execute_task(task : Key) : Nil
    application.execute_task(@tasks[task].descriptor)
  end

  def mark_as_completed(task : Key) : Nil
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

  def prepare(@application : Application) : Nil
  end

  def stats : Array(TaskStats)
    @tasks.map { |_, t|
      TaskStats.new(
        descriptor: t.descriptor,
        completed: t.state == State::Completed,
        initiated_by: t.initiated_by
      )
    }
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

  class KVStore < ::Tasko::KVStore
    def initialize(@engine : MemoryEngine)
      @data = Hash(String, String).new
    end

    def save(key : String, value : D) : Nil forall D
      @data[key] = @engine.serialize_data(value)
    end

    def load(key : String, as type : Class)
      @engine.deserialize_data(@data[key], as: type)
    end
  end
end
