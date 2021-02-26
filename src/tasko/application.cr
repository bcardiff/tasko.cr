class Tasko::Application
  property engine : Engine = MemoryEngine.new

  @definitions = Hash(String, Proc(String, Context, Nil)).new

  def define_task(name : String, body : Proc(D, Context, Nil)) forall D
    raise "Task #{name} already defined" if @definitions.has_key?(name)

    @definitions[name] = ->(serialized : String, context : Context) {
      data = engine.load_task_data(serialized, as: D)
      body.call(data, context)
    }
  end

  def schedule_task(name : String, data : D) : Key forall D
    changeset = create_changeset
    res = changeset.create_task name, data
    engine.submit_changeset(changeset)
    res
  end

  def run(exit_on_done : Bool = false)
    if exit_on_done
      while (task = engine.receive_task?)
        execute_task task
      end
    end
  end

  protected def execute_task(task : TaskDescriptor)
    changeset = create_changeset
    context = Context.new(changeset, task.key, engine.tasks_dependencies(task.key))

    begin
      @definitions[task.name].call(task.serialized_data, context)
    rescue
      # TODO Log / Retry
    else
      engine.submit_changeset(changeset)
    ensure
      engine.mark_as_completed(task.key)
    end
  end

  # :nodoc:
  def create_changeset : Changeset
    Changeset.new(self)
  end
end