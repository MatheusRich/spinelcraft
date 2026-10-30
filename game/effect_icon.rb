# The icon of an effect in the top right corner of the HUD, with the seconds
# that are left below it, as the effects of Minecraft.
# minecraft.wiki/w/Effect
class EffectIcon
  # The pixels between the icon and the top and right edges of the frame,
  # and between the icon and its seconds, at scale 1.
  MARGIN = 16.0
  TEXT_GAP = 2.0
  TEXT_SCALE = 2.0

  # ui draws the icon. texture is its layer (see Tex.hud_icon).
  def initialize(ui, texture)
    @ui = ui
    @texture = texture
  end

  # Draws the icon at the right edge of a frame of frame_width pixels, and
  # below it the seconds, rounded up.
  def draw(seconds, frame_width, scale)
    size = IconRow::ICON_SIZE * scale
    left = frame_width - size - MARGIN * scale
    top = MARGIN * scale
    part = Tex::ICON_PART
    @ui.quad(left, top, size, size, @texture, part, part, Color::WHITE)
    text = seconds.ceil.to_s
    text_scale = TEXT_SCALE * scale
    @ui.text(left + (size - @ui.text_width(text, text_scale)) / 2.0, top + size + TEXT_GAP * scale, text, text_scale, Color::WHITE)
  end
end
