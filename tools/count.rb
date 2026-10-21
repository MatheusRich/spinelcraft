# Counts generated blocks by type. Runs under CRuby or Spinel.
require_relative "../game/rng"
require_relative "../game/textures"
require_relative "../game/block"
require_relative "../game/biome"
require_relative "../game/noise"
require_relative "../game/world"
require_relative "../game/terrain"
require_relative "../game/trees"

# The 24 x 24 chunks from x = z = 0.
w = World.new((ENV["SEED"] || "1337").to_i)
counts = Array.new(Block::COUNT, 0)
24.times do |cx|
  24.times do |cz|
    w.load_chunk(cx, cz)
    w.chunk_bytes(cx, cz).each_byte { |b| counts[b] += 1 }
  end
end
Block::COUNT.times do |i|
  puts "#{Block::NAMES[i]}: #{counts[i]}"
end
puts "hash3 #{Noise.hash3(10, 0, 20, 21)}"
