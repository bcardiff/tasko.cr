module Tasko
  macro params(name, *properties)
    record {{name.id}}, {{*properties}} do
      include JSON::Serializable
    end
  end
end
