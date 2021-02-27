module Tasko
  def self.generate_dot(io : IO, application : Application)
    tasks = application.engine.stats

    io.puts "digraph Tasks {"
    tasks.each do |t|
      io.puts %Q(  "#{t.descriptor.key}" [label="#{t.descriptor.name} #{t.descriptor.serialized_data}" color="#{t.completed ? "green" : "black"}"])
    end
    tasks.each do |t|
      if parent = t.initiated_by
        io.puts %Q(  "#{parent}" -> "#{t.descriptor.key}" [style=dashed])
      end
      application.engine.tasks_dependencies(t.descriptor.key).each do |dep|
        io.puts %Q(  "#{dep}" -> "#{t.descriptor.key}")
      end
    end
    io.puts "}"
  end
end
