require "redis"
require "../tasko/engine"
require "../tasko/helpers"

class Tasko::RedisEngine < Tasko::Engine
  include JSONTaskSerialization
  include UUIDTaskKeys
  include NaivePollingScheduler

  getter! application : Application
  getter! store_protocol : ::Tasko::KVStore::Protocol
  getter redis : ::Redis::PooledClient

  def initialize(@redis : ::Redis::PooledClient)
    @store_protocol = ::Tasko::RedisEngine::KVStoreProtocol.new(self)
  end

  def submit_changeset(changeset : Changeset, current_task_key : Key?)
    redis.multi do |multi|
      changeset.created_tasks.each do |change|
        multi.hmset(descriptor_key(change.key), {
          "key":             change.key.value,
          "name":            change.name,
          "serialized_data": change.serialized_data,
          "initiated_by":    current_task_key.try(&.value),
        })
        multi.rpush(pending_tasks_key, change.key.value)
      end

      changeset.created_dependencies.each do |change|
        multi.sadd(pending_dependencies_key(change.task), change.requires.value)
        multi.sadd(all_dependencies_key(change.task), change.requires.value)
        multi.sadd(following_tasks_key(change.requires), change.task.value)
      end
    end
  end

  def receive_task? : Key?
    task = move_ready_to_running?
    return task if task
    move_pending_to_ready
    task = move_ready_to_running?

    return task
  end

  protected def move_pending_to_ready
    # TODO Lock avoid adding dependencies on key between check and moving it to ready
    # TODO use cursors
    redis.lrange(pending_tasks_key, 0, -1).each do |pending_task|
      key = Key.new(value: pending_task.as(String))
      if redis.scard(pending_dependencies_key(key)) == 0
        move_pending_to_ready(key)
        return # moving one is enough to guarantee progress
      end
    end
  end

  protected def move_pending_to_ready(task : Key)
    # first push to ready THEN remove from pending in case things go wrong
    redis.rpush(ready_tasks_key, task.value)
    redis.lrem(pending_tasks_key, 1, task.value)
  end

  protected def move_ready_to_running? : Key?
    task = redis.rpoplpush ready_tasks_key, running_tasks_key
    task.try { |v| Key.new(value: v.as(String)) }
  end

  def mark_as_completed(task : Key) : Nil
    ready_tasks = [] of Key

    redis.smembers(following_tasks_key(task)).each do |next_task|
      next_task_key = Key.new(value: next_task.as(String))
      redis_key = pending_dependencies_key(next_task_key)
      redis.srem(redis_key, task.value)
      if redis.scard(redis_key) == 0
        ready_tasks << next_task_key
      end
    end

    redis.del(following_tasks_key(task))

    ready_tasks.each do |next_task|
      move_pending_to_ready(next_task)
    end

    # first push to completed THEN remove from running in case things go wrong
    redis.rpush(completed_tasks_key, task.value)
    redis.lrem(running_tasks_key, 1, task.value)
  end

  def tasks_dependencies(task : Key) : Array(Key)
    redis.smembers(all_dependencies_key(task)).map { |e| Key.new(value: e.as(String)) }
  end

  def execute_task(task : Key) : Nil
    application.execute_task(get_task_descriptor(task))
  end

  def done? : Bool
    redis.llen(pending_tasks_key) == 0 &&
      redis.llen(ready_tasks_key) == 0 &&
      redis.llen(running_tasks_key) == 0
  end

  def prepare(@application : Application) : Nil
    # restore all ready and running tasks to pending
    move_all_list(running_tasks_key, pending_tasks_key)
    move_all_list(ready_tasks_key, pending_tasks_key)
  end

  def stats : Array(TaskStats)
    completed = Set(Key).new
    redis.lrange(completed_tasks_key, 0, -1).each do |k|
      completed << Key.new(value: k.as(String))
    end

    redis.keys("tasko:descriptor:*").map { |k|
      res = redis.hmget(k.as(String), "key", "initiated_by")
      task = Key.new(value: res[0].as(String))
      initiated_by = res[1].as(String?).presence.try { |v| Key.new(value: v) }

      TaskStats.new(
        descriptor: get_task_descriptor(task),
        completed: completed.includes?(task),
        initiated_by: initiated_by
      )
    }
  end

  protected def move_all_list(source, target)
    while redis.rpoplpush(source, target)
    end
  end

  protected def get_task_descriptor(task : Key) : TaskDescriptor
    res = redis.hmget(descriptor_key(task), "name", "serialized_data")
    TaskDescriptor.new(key: task, name: res[0].as(String), serialized_data: res[1].as(String))
  end

  private def descriptor_key(task : Key)
    "tasko:descriptor:#{task.value}"
  end

  private def pending_tasks_key
    "tasko:pending-tasks"
  end

  private def ready_tasks_key
    "tasko:ready-tasks"
  end

  private def running_tasks_key
    "tasko:running-tasks"
  end

  private def completed_tasks_key
    "tasko:completed-tasks"
  end

  private def pending_dependencies_key(task : Key)
    "tasko:pending-dependencies:#{task.value}"
  end

  private def all_dependencies_key(task : Key)
    "tasko:dependencies:#{task.value}"
  end

  # aka inverse dependencies
  private def following_tasks_key(task : Key)
    "tasko:following_tasks:#{task.value}"
  end

  class KVStoreProtocol < ::Tasko::KVStore::Protocol
    def initialize(@engine : RedisEngine)
    end

    def set(key : String, value : String) : Nil
      @engine.redis.set(key, value)
    end

    def get(key : String) : String
      @engine.redis.get(key).as(String)
    end

    def lrange(key : String, from : Int32, to : Int32) : Array(String)
      @engine.redis.lrange(key, from, to).map &.as(String)
    end

    def lrem(key : String, count : Int32, value : String) : Int64
      @engine.redis.lrem(key, count, value)
    end

    def rpoplpush(source : String, destination : String) : String?
      @engine.redis.rpoplpush(source, destination)
    end

    def rpush(key : String, value : String) : Int64
      @engine.redis.rpush(key, value)
    end

    def llen(key : String) : Int64
      @engine.redis.llen(key)
    end

    def scard(key : String) : Int64
      @engine.redis.scard(key)
    end

    def sadd(key : String, value : String) : Int64
      @engine.redis.sadd(key, value)
    end

    def smembers(key : String) : Array(String)
      @engine.redis.smembers(key).map &.as(String)
    end

    def srem(key : String, value : String) : Int64
      @engine.redis.srem(key, value)
    end

    def sismember(key : String, value : String) : Bool
      @engine.redis.sismember(key, value) != 0
    end
  end
end
