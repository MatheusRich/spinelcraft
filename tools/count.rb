# Counts generated blocks by type. Runs under CRuby or Spinel.
require_relative "../game/rng"
require_relative "../game/textures"
require_relative "../game/world"

# The 24 x 24 chunks from x = z = 0.
w = World.new((ENV["SEED"] || "1337").to_i)
counts = Array.new(Block::COUNT, 0)
cx = 0
while cx < 24
  cz = 0
  while cz < 24
    w.load_chunk(cx, cz)
    w.chunk_bytes(cx, cz).each_byte { |b| counts[b] += 1 }
    cz += 1
  end
  cx += 1
end
i = 0
while i < Block::COUNT
  puts "#{Block::NAMES[i]}: #{counts[i]}"
  i += 1
end
puts "hash3 #{hash3(10, 0, 20, 21)}"
