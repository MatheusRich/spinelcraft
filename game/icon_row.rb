# A row of 10 HUD icons that shows points out of 20, such as the hearts or
# the armor. Each icon is 2 points, and an odd point shows as a half icon:
# the left 5 of the 9 columns, as in Minecraft.
class IconRow
  ICONS = 10
  ICON_SIZE = 18.0
  ICON_STEP = 20.0
  HALF_ICON_WIDTH = 10.0
  HALF_ICON_COLUMNS = 5.0 / 16.0

  # The size of an icon is its base size times scale. The HUD sets it each
  # frame.
  attr_writer :scale

  # ui draws the icons. full and empty are their textures.
  def initialize(ui, full, empty)
    @ui = ui
    @scale = 1.0
    @full = full
    @empty = empty
  end

  # Draws the row of points from the left edge and the top edge.
  def draw(points, left, top)
    part = Tex::ICON_PART
    ICONS.times do |icon|
      x = left + icon * ICON_STEP * @scale
      @ui.quad(x, top, ICON_SIZE * @scale, ICON_SIZE * @scale, @empty, part, part, Color::WHITE)
      icon_points = points - icon * 2
      if icon_points >= 2
        @ui.quad(x, top, ICON_SIZE * @scale, ICON_SIZE * @scale, @full, part, part, Color::WHITE)
      elsif icon_points == 1
        @ui.quad(x, top, HALF_ICON_WIDTH * @scale, ICON_SIZE * @scale, @full, HALF_ICON_COLUMNS, part, Color::WHITE)
      end
    end
  end
end
