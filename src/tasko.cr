require "log"

module Tasko
  VERSION = "0.1.0"

  Log = ::Log.for(self)
end

require "./tasko/**"
