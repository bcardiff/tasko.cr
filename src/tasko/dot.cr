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
end
