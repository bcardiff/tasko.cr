struct Tasko::Key
  getter value : String

  def initialize(@value : String)
  end

  def_equals_and_hash @value

  def to_s(io : IO) : Nil
    io << @value
  end
end
