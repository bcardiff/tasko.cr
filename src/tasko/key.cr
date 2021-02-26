struct Tasko::Key
  def initialize(@value : String)
  end

  def_equals_and_hash @value
end
