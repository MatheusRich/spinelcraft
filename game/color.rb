# A color with its alpha, each part from 0.0 to 1.0. Mesh3 draws with it.
Color = Data.define(:red, :green, :blue, :alpha)
# TODO: Rename to WHITE when Spinel keeps the constants of one name in
# different modules apart. Now Color::WHITE and Tex::WHITE share one type.
Color::SOLID_WHITE = Color.new(1.0, 1.0, 1.0, 1.0)
Color::SOLID_BLACK = Color.new(0.0, 0.0, 0.0, 1.0)
