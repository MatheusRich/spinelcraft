# A color with its alpha, each part from 0.0 to 1.0. Mesh3 draws with it.
Color = Data.define(:red, :green, :blue, :alpha)
Color::WHITE = Color.new(1.0, 1.0, 1.0, 1.0)
Color::BLACK = Color.new(0.0, 0.0, 0.0, 1.0)
