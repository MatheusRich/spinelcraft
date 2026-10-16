require "minitest/autorun"

# These tests run the game classes under CRuby. Spinel does not compile
# Minitest, so the self-test (SELFTEST=1) checks the compiled game.
# game/gfx.rb needs the FFI of Spinel, so empty modules take its place.
# The tests must not call Gfx.
module Gfx; end
module Key; end

# The game files do not require each other. This file loads them in the
# order of main.rb, so a new file in main.rb needs no change here.
File.read(File.expand_path("../main.rb", __dir__)).scan(/^require_relative "(game\/\w+)"$/) do |(file)|
  require_relative "../#{file}" unless file == "game/gfx" || file == "game/testing"
end

# A height above the land and the trees, where a test has open air.
SKY_Y = WY - 6

# A world with the chunk at x = z = 0 to 15 loaded.
def world_with_one_chunk
  world = World.new(1337)
  world.load_chunk(0, 0)
  world
end
