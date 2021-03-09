# tasko

This library allows you to define a program in term of tasks. Each task invocation
has parameters and a set of dependencies. The dependencies are tasks that must be
executed before.

The application is executed by an engine. Currently there are two: `Tasko::MemoryEngine`
and `Tasko::RedisEngine`. The latter allows you define a worker that can be stopped
or crashed without loosing the task invocation tree. It also allows you to have multiple
worker instances to spread the load and execute them concurrently. Each task will be
executed by one worker.

When a task is executing, besides the params it receives a `Tasko::Context` that allows you to create and schedule new tasks invocations. The changes made via this context are atomic.

Although the execution of the task itself is not atomic and might be interrupted at any point, making the changes via the context atomic is enough to create resilient and resumable programs.

It is convenient to have a Key-Value Store were each task invocation can generate data
that dependant tasks might need. `Tasko::KVStore` is a base class you can use to build
your own Key-Value Store that use the `Tasko::Engine` of your application: either memory or redis.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     tasko:
       github: bcardiff/tasko.cr
     redis: # if you want to use Tasko::RedisEngine
       github: stefanwille/crystal-redis
   ```

2. Run `shards install`

## Usage

```crystal
require "tasko"
require "tasko/redis" # if you want to use Tasko::RedisEngine
```

See [/samples](/samples).

## Contributing

1. Fork it (<https://github.com/bcardiff/tasko.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Brian J. Cardiff](https://github.com/bcardiff) - creator and maintainer
