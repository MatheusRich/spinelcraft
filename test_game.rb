# The entry of the test build: `./build.sh test` compiles it to
# ./spinelcraft-test. The game build (main.rb) leaves the tests out.
require_relative "main"
require_relative "game/testing"

TestGame.new.run
