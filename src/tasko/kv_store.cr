abstract class Tasko::KVStore
  abstract def save(key : String, value : D) : Nil forall D
  abstract def load(key : String, as type : Class)

  struct IndexedData(K, V)
    def initialize(@store : KVStore, @prefix : String, @name : String)
    end

    def []=(index : K, value : V)
      @store.save("#{@prefix}:#{index}:#{@name}", value)
    end

    def [](index : K) : V
      @store.load("#{@prefix}:#{index}:#{@name}", as: V)
    end
  end
end

module Tasko
  macro store(class_name)
    macro data(name_and_type, *, indexed_by = nil)
      \{% store_prefix = @type.name %}
      \{% if name_and_type.is_a?(TypeDeclaration) %}
        \{% name = name_and_type.var.id %}
        \{% return_type = name_and_type.type %}
        \{% if indexed_by %}
          def \{{name}}
            ::Tasko::KVStore::IndexedData(\{{indexed_by}}, \{{return_type}}).new(@store, \{{store_prefix.stringify}}, \{{name.stringify}})
          end
        \{% else %}
          def \{{name}}=(value : \{{return_type}})
            @store.save("\{{store_prefix}}:\{{name}}", value)
          end

          def \{{name}} : \{{return_type}}
            @store.load("\{{store_prefix}}:\{{name}}", as: \{{return_type}})
          end
        \{% end %}
      \{% else %}
        \{% raise "data should be used with type declaration: `data name : Type, [index]`" %}
      \{% end %}
    end

    class {{class_name}}
      @store : ::Tasko::KVStore

      def initialize(engine : ::Tasko::Engine)
        @store = engine.store
      end

      {{yield}}
    end
  end
end
