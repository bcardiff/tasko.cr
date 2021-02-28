struct Tasko::Key
  getter value : String

  def initialize(@value : String)
  end

  def_equals_and_hash @value

  def to_s(io : IO) : Nil
    io << @value
  end

  def self.new(pull : ::JSON::PullParser)
    from_json(pull)
  end

  def to_json(builder : JSON::Builder)
    @value.to_json(builder)
  end

  def self.from_json(pull : JSON::PullParser) : self
    Tasko::Key.new(value: pull.read_string)
  end
end
