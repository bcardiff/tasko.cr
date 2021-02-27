record Tasko::TaskDescriptor, key : Key, name : String, serialized_data : String

record Tasko::TaskStats, descriptor : TaskDescriptor, completed : Bool, initiated_by : Key?
