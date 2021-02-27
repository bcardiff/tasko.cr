require "mosquito"
require "../tasko/engine"

private def redis_url
  ENV["REDIS_URL"]? || "redis://localhost:6379"
end

Mosquito.configure do |settings|
  settings.redis_url = redis_url
end

# Patch to use pooled client in Mosquito
module Mosquito
  class Redis
    def initialize
      Mosquito.validate_settings
      @connection = ::Redis::PooledClient.new url: Mosquito.settings.redis_url
    end
  end
end

class Tasko::MosquitoEngine < Tasko::Engine
  class_property! application : Application

  def create_task_key : Key
    Key.new(value: "task:#{UUID.random}")
  end

  def load_task_data(serialized, as type : Class)
    type.from_json(serialized)
  end

  def save_task_data(data : D) forall D
    data.to_json
  end

  def submit_changeset(changeset : Changeset)
    redis.multi do |multi|
      changeset.created_tasks.each do |change|
        multi.hmset(descriptor_key(change.key), {"name": change.name, "serialized_data": change.serialized_data})
        multi.sadd(pending_tasks_key, change.key.value)
      end

      changeset.created_dependencies.each do |change|
        multi.sadd(pending_dependencies_key(change.task), change.requires.value)
        multi.sadd(all_dependencies_key(change.task), change.requires.value)
        multi.sadd(following_tasks_key(change.requires), change.task.value)
      end
    end
  end

  def receive_task? : Key?
    # TODO lock or concurrent friendly code. currently the task is removed
    #      from pending when the execution is scheduled.
    redis.smembers(pending_tasks_key).each do |pending_task|
      key = Key.new(value: pending_task.as(String))
      if redis.scard(pending_dependencies_key(key)) == 0
        return key
      end
    end

    nil
  end

  def mark_as_completed(task : Key, application : Application) : Nil
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
    redis.srem(dispatched_tasks_key, task.value)

    # we can send task right away, there is not need to wait for a receive_task? call
    ready_tasks.each do |next_task|
      execute_task(task, application)
    end

    # TODO recently created tasks could be check if they can run
  end

  def tasks_dependencies(task : Key) : Array(Key)
    redis.smembers(all_dependencies_key(task)).map { |e| Key.new(value: e.as(String)) }
  end

  def execute_task(task : Key, application : Application) : Nil
    ExecuteTask.new(raw_key: task.value).enqueue
    redis.sadd(dispatched_tasks_key, task.value)
    redis.srem(pending_tasks_key, task.value)
  end

  def done? : Bool
    redis.scard(pending_tasks_key) == 0 &&
      redis.scard(dispatched_tasks_key) == 0
  end

  def prepare(application : Application) : Nil
    # pick up dispatched tasks that didn't complete in the previous run
    # NOTE: this does not allow multiple runners
    redis.smembers(dispatched_tasks_key).each do |task|
      redis.sadd(pending_tasks_key, task.as(String))
      redis.srem(dispatched_tasks_key, task.as(String))
    end

    @@application = application
    spawn { Mosquito::Runner.start }
  end

  # :nodoc:
  def get_task_descriptor(task : Key) : TaskDescriptor
    res = redis.hmget(descriptor_key(task), "name", "serialized_data")
    TaskDescriptor.new(key: task, name: res[0].as(String), serialized_data: res[1].as(String))
  end

  private def descriptor_key(task : Key)
    "tasko:descriptor:#{task.value}"
  end

  private def pending_tasks_key
    "tasko:pending-tasks"
  end

  private def dispatched_tasks_key
    "tasko:dispatched-tasks"
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

  def redis
    # Thanks to the monkey patch we can reuse the pool used
    # by mosquito, although the patch is needed besides
    # the redis connection used here.
    # Otherwise we can use a custom connection
    # @redis ||= Redis::PooledClient.new(url: redis_url)
    Mosquito::Redis.instance
  end

  class ExecuteTask < Mosquito::QueuedJob
    params raw_key : String

    def perform
      application = Tasko::MosquitoEngine.application
      engine = application.engine.as(MosquitoEngine)

      task = engine.get_task_descriptor(Key.new(value: raw_key))

      application.execute_task(task)
    end
  end
end
