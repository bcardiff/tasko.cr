abstract class Tasko::KVStore
  # :nodoc:
  module Converter
    def self.serialize(value) : String
      case value
      when String
        value
      else
        value.to_json
      end
    end

    def self.deserialize(serialized : String, as type : T.class) : T forall T
      type.from_json(serialized)
    end

    def self.deserialize(serialized : String, as type : String.class)
      serialized
    end
  end

  # :nodoc:
  abstract class Protocol
    abstract def set(key : String, value : String) : Nil
    abstract def get(key : String) : String
  end

  struct Value(T)
    getter key : String

    def initialize(@protocol : Protocol, @key : String)
    end

    def set(value : T) : Nil
      @protocol.set(key, Converter.serialize(value))
    end

    def get : T
      Converter.deserialize(@protocol.get(key), as: T)
    end
  end

  @protocol : ::Tasko::KVStore::Protocol

  def initialize(engine : ::Tasko::Engine)
    @protocol = engine.store_protocol
  end

  protected def single_value(key : String, as type : T.class) : Value(T) forall T
    ::Tasko::KVStore::Value(T).new(@protocol, key)
  end
end
