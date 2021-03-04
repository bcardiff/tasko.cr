require "./spec_helper"

private class Point
  include JSON::Serializable

  property x : Int32
  property y : Int32

  def initialize(@x : Int32, @y = Int32)
  end

  def_equals_and_hash @x, @y
end

private class MyStore < Tasko::KVStore
  def a_string
    single_value("a_string", String)
  end

  def a_point
    single_value("a_point", Point)
  end

  def an_indexed_point(index : String)
    single_value("an_indexed_point:#{index}")
  end

  def a_list_of_points
    list_value("a_list_of_points", Point)
  end

  def another_list_of_points
    list_value("another_list_of_points", Point)
  end

  def a_set_of_points
    set_value("a_set_of_points", Point)
  end
end

def it_with_store(description, file = __FILE__, line = __LINE__, &block : MyStore -> _)
  it("#{description} (with redis)", file: file, line: line) do
    with_redis do |redis|
      engine = Tasko::RedisEngine.new(redis)
      block.call(MyStore.new(engine))
    end
  end

  pending("#{description} (with memory)", file: file, line: line) do
    engine = Tasko::MemoryEngine.new
    block.call(MyStore.new(engine))
  end
end

describe Tasko::KVStore do
  it_with_store "set/get a single string value directly" do |store|
    store.a_string.set "lorem ipsum"
    store.a_string.get.should eq("lorem ipsum")
    store.@protocol.get(store.a_string.key).should eq("lorem ipsum")
  end

  it_with_store "set/get a single value encoded as json" do |store|
    store.a_point.set Point.new(10, 20)
    store.a_point.get.should eq(Point.new(10, 20))
  end

  it_with_store "operates with lists of items encoded as json" do |store|
    store.a_list_of_points.rpush(Point.new(10, 20))
    store.a_list_of_points.rpush(Point.new(30, 40))
    store.a_list_of_points.rpush(Point.new(50, 60))
    store.a_list_of_points.llen.should eq(3)
    store.a_list_of_points.lrange(0, -1).should eq([Point.new(10, 20), Point.new(30, 40), Point.new(50, 60)])
    store.a_list_of_points.lrem(1, Point.new(30, 40)).should eq(1)
    store.a_list_of_points.rpoplpush(store.another_list_of_points).should eq(Point.new(50, 60))
    store.a_list_of_points.lrange(0, -1).should eq([Point.new(10, 20)])
    store.another_list_of_points.lrange(0, -1).should eq([Point.new(50, 60)])
  end

  it_with_store "operates with sets of items encoded as json" do |store|
    store.a_set_of_points.scard.should eq(0)
    store.a_set_of_points.sadd(Point.new(10, 20)).should eq(1)
    store.a_set_of_points.sadd(Point.new(10, 20)).should eq(0)
    store.a_set_of_points.scard.should eq(1)
    store.a_set_of_points.smembers.should eq([Point.new(10, 20)])
    store.a_set_of_points.sismember(Point.new(10, 20)).should eq(true)
    store.a_set_of_points.sismember(Point.new(30, 40)).should eq(false)
    store.a_set_of_points.srem(Point.new(10, 20)).should eq(1)
  end
end
