# The options of the pause menu, and the file that keeps them between runs.
class Options
  # The render distance of a new player, and the range of its slider, in
  # blocks.
  VIEW_START = 1600.0
  VIEW_MIN = 200.0
  VIEW_MAX = 5000.0
  # The range of the field of view slider, and its start, in degrees from
  # the bottom to the top of the view. Minecraft shows 70 as "Normal" and
  # 110 as "Quake Pro". minecraft.wiki/w/Options
  FOV_MIN = 30.0
  FOV_MAX = 110.0
  FOV_NORMAL = 70.0

  # The brightness, the volume and the music go from 0 to 1. Brightness 0
  # is the light without a lift. The render distance is in blocks, and the
  # field of view in degrees. debug shows the debug lines of F3.
  # graphics is a GraphicsMode.
  attr_accessor :brightness, :volume, :music, :view, :fov_degrees, :fullscreen, :debug, :graphics

  # Options that path keeps. The brightness, the volume and the music
  # start at half, the graphics start FANCY, and the debug lines start off.
  def initialize(path)
    @path = path
    @brightness = 0.5
    @volume = 0.5
    @music = 0.5
    @view = VIEW_START
    @fov_degrees = FOV_NORMAL
    @fullscreen = false
    @debug = false
    @graphics = GraphicsMode::FANCY
  end

  # Where the render distance is on its slider, from 0 to 1.
  def view_share = (@view - VIEW_MIN) / (VIEW_MAX - VIEW_MIN)

  # Sets the render distance to share t of its slider, in steps of 100
  # blocks.
  def slide_view(t)
    @view = ((VIEW_MIN + t * (VIEW_MAX - VIEW_MIN)) / 100.0).round * 100.0
  end

  # Where the field of view is on its slider, from 0 to 1.
  def fov_share = (@fov_degrees - FOV_MIN) / (FOV_MAX - FOV_MIN)

  # Sets the field of view to share t of its slider, in steps of 1 degree.
  def slide_fov(t)
    @fov_degrees = (FOV_MIN + t * (FOV_MAX - FOV_MIN)).round.to_f
  end

  # The half angle of the view in radians.
  def half_fov = @fov_degrees * Math::PI / 360.0

  # Writes the options to their file, one "name:value" line each, as in
  # the options.txt of Minecraft.
  def write_file
    File.open(@path, "w") do |f|
      f.write("brightness:#{@brightness}\nvolume:#{@volume}\nmusic:#{@music}\nview:#{@view}\nfov:#{@fov_degrees}\nfullscreen:#{@fullscreen}\ndebug:#{@debug}\ngraphics:#{@graphics.name.downcase}\n")
    end
    nil
  end

  # Reads the options that write_file wrote. An option that is not in the
  # file keeps its value.
  def read_file
    return unless File.exist?(@path)

    File.binread(@path).split("\n").each do |line|
      parts = line.split(":")
      read_option(parts[0], parts[1]) if parts.size == 2
    end
    nil
  end

  # Sets the option name to the text value, inside its range.
  def read_option(name, value)
    if name == "brightness"
      @brightness = value.to_f.clamp(0.0, 1.0)
    elsif name == "volume"
      @volume = value.to_f.clamp(0.0, 1.0)
    elsif name == "music"
      @music = value.to_f.clamp(0.0, 1.0)
    elsif name == "view"
      @view = value.to_f.clamp(VIEW_MIN, VIEW_MAX)
    elsif name == "fov"
      @fov_degrees = value.to_f.clamp(FOV_MIN, FOV_MAX)
    elsif name == "fullscreen"
      @fullscreen = value == "true"
    elsif name == "debug"
      @debug = value == "true"
    elsif name == "graphics"
      @graphics = GraphicsMode.parse(value) || GraphicsMode::FANCY
    end
    # A nil return keeps Spinel from boxing the value of each branch.
    nil
  end
end
