require "uri"

abstract class Tasko::KVStore
  # :nodoc:
  module Converter
    def self.serialize(value : String) : String
      value
    end

    def self.deserialize(serialized : String, as type : T.class) : T forall T
      type.from_json(serialized)
    end

    def self.serialize(value) : String
      value.to_json
    end

    def self.deserialize(serialized : String, as type : String.class)
      serialized
    end

    def self.serialize(value : URI) : String
      value.to_s
    end

    def self.deserialize(serialized : String, as type : URI.class)
      URI.parse(serialized)
    end
  end

  # :nodoc:
  abstract class Protocol
    abstract def set(key : String, value : String) : Nil
    abstract def get(key : String) : String

    abstract def lrange(key : String, from : Int32, to : Int32) : Array(String)
    abstract def lrem(key : String, count : Int32, value : String) : Int64
    abstract def rpoplpush(source : String, destination : String) : String?
    abstract def rpush(key : String, value : String) : Int64
    abstract def llen(key : String) : Int64

    abstract def scard(key : String) : Int64
    abstract def sadd(key : String, value : String) : Int64
    abstract def smembers(key : String) : Array(String)
    abstract def srem(key : String, value : String) : Int64
    abstract def sismember(key : String, value : String) : Bool
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

  class List(T)
    getter key : String

    def initialize(@protocol : Protocol, @key : String)
    end

    def lrange(from : Int32, to : Int32) : Array(T)
      @protocol.lrange(key, from, to).map do |v|
        Converter.deserialize(v, as: T)
      end
    end

    def lrem(count : Int32, value : T) : Int64
      @protocol.lrem(key, count, Converter.serialize(value))
    end

    def rpoplpush(destination : List(T)) : T?
      # TODO assert destination belongs to the same protocol
      @protocol.rpoplpush(key, destination.key).try do |v|
        Converter.deserialize(v, as: T)
      end
    end

    def rpush(value : T) : Int64
      @protocol.rpush(key, Converter.serialize(value))
    end

    def llen : Int64
      @protocol.llen(key)
    end
  end

  class Set(T)
    getter key : String

    def initialize(@protocol : Protocol, @key : String)
    end

    def scard : Int64
      @protocol.scard(key)
    end

    def sadd(value : T) : Int64
      @protocol.sadd(key, Converter.serialize(value))
    end

    def smembers : Array(T)
      @protocol.smembers(key).map do |v|
        Converter.deserialize(v, as: T)
      end
    end

    def srem(value : T) : Int64
      @protocol.srem(key, Converter.serialize(value))
    end

    def sismember(value : T) : Bool
      @protocol.sismember(key, Converter.serialize(value))
    end
  end

  @protocol : ::Tasko::KVStore::Protocol

  def initialize(engine : ::Tasko::Engine)
    @protocol = engine.store_protocol
  end

  protected def single_value(key : String, as type : T.class) : Value(T) forall T
    ::Tasko::KVStore::Value(T).new(@protocol, key)
  end

  protected def list_value(key : String, as type : T.class) : List(T) forall T
    ::Tasko::KVStore::List(T).new(@protocol, key)
  end

  protected def set_value(key : String, as type : T.class) : Set(T) forall T
    ::Tasko::KVStore::Set(T).new(@protocol, key)
  end
end
