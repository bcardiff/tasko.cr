module Tasko
  def self.generate_dot(io : IO, application : Application)
    tasks = application.engine.stats
    completed = Set(Key).new

    io.puts "digraph Tasks {"
    tasks.each do |t|
      if t.completed
        completed << t.descriptor.key
        extra = %Q( color=green)
      end
      label = "#{t.descriptor.name} #{t.descriptor.serialized_data}"
      io.puts %Q(  "#{t.descriptor.key}" [label=#{label.inspect}#{extra}])
    end
    tasks.each do |t|
      if parent = t.initiated_by
        io.puts %Q(  "#{parent}" -> "#{t.descriptor.key}" [style=dashed])
      end
      application.engine.tasks_dependencies(t.descriptor.key).each do |dep|
        extra = %Q( [color=green]) if completed.includes?(dep)
        io.puts %Q(  "#{dep}" -> "#{t.descriptor.key}"#{extra})
      end
    end
    io.puts "}"
  end

  def self.generate_collapsed_dot(io : IO, application : Application)
    generate_collapsed_dot(io, application) do |task_stats|
      task_stats.descriptor.name
    end
  end

  def self.generate_collapsed_dot(io : IO, application : Application, & : TaskStats -> String)
    tasks = application.engine.stats
    tasks_by_key = Hash(Key, TaskStats).new
    nodes = Set(String).new

    initiated_by = Set({from: String, to: String}).new
    dependencies = Set({from: String, to: String}).new

    tasks.each do |t|
      tasks_by_key[t.descriptor.key] = t
      nodes << yield t
    end

    tasks.each do |t|
      if parent = t.initiated_by
        initiated_by << {from: (yield tasks_by_key[parent]), to: yield t}
      end
      application.engine.tasks_dependencies(t.descriptor.key).each do |dep|
        dependencies << {from: (yield tasks_by_key[dep]), to: yield t}
      end
    end

    io.puts "digraph Tasks {"
    nodes.each do |label|
      io.puts %Q(  #{label.inspect})
    end
    initiated_by.each do |entry|
      io.puts %Q(  #{entry[:from].inspect} -> #{entry[:to].inspect} [style=dashed])
    end
    dependencies.each do |entry|
      io.puts %Q(  #{entry[:from].inspect} -> #{entry[:to].inspect})
    end
    io.puts "}"
  end
end
