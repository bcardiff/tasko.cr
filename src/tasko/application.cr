class Tasko::Application
  getter engine : Engine
  @definitions = Hash(String, Proc(String, Context, Nil)).new

  def initialize(@engine : Engine = MemoryEngine.new)
  end

  def define_task(name : String, body : Proc(D, Context, Nil)) forall D
    raise "Task #{name} already defined" if @definitions.has_key?(name)

    @definitions[name] = ->(serialized : String, context : Context) {
      data = engine.deserialize_data(serialized, as: D)
      body.call(data, context)
    }
  end

  def schedule_task(name : String, data : D) : Key forall D
    changeset = create_changeset
    res = changeset.create_task name, data
    engine.submit_changeset(changeset, nil)
    res
  end

  def run(exit_on_done : Bool = false)
    engine.run(self, exit_on_done)
  end

  # :nodoc:
  def execute_task(task : TaskDescriptor)
    Log.info { "Executing #{task.key} #{task.name}(#{task.serialized_data})" }

    changeset = create_changeset
    context = Context.new(changeset, task.key, engine.tasks_dependencies(task.key))

    begin
      @definitions[task.name].call(task.serialized_data, context)
    rescue e
      # TODO Retry/mark_as_failed
      Log.error(exception: e) { "Error while executing #{task.key}" }
    else
      engine.submit_changeset(changeset, task.key)
    ensure
      engine.mark_as_completed(task.key)
    end
  end

  # :nodoc:
  def create_changeset : Changeset
    Changeset.new(self)
  end
end
