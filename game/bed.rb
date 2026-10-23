# The rules of sleeping in a bed. minecraft.wiki/w/Bed
module Bed
  # The player can sleep when the sky light is 11 or below. Rain darkens
  # the sky, so in rain the time to sleep starts earlier and ends later.
  SLEEP_LIGHT = 11
  # A monster this near keeps the player awake: 8 blocks across and 5
  # blocks up or down.
  MONSTER_REACH = 8.0
  MONSTER_HEIGHT = 5.0

  # Uses the bed at x, y, z under a sky light of sky_light. At night with
  # no monster near, the night passes on clock. Returns what the player
  # reads.
  def self.use(x, y, z, sky_light, mobs, clock)
    return "SPAWN SET: YOU CAN ONLY SLEEP AT NIGHT" if sky_light > SLEEP_LIGHT
    return "YOU CANNOT SLEEP NOW: MONSTERS ARE NEARBY" if monster_near?(mobs, x, y, z)

    clock.skip_night
    "GOOD MORNING"
  end

  # True when a live monster of mobs is near the bed at x, y, z.
  def self.monster_near?(mobs, x, y, z)
    mobs.any? do |mob|
      !mob.passive? && !mob.dying? && (mob.x - x - 0.5).abs <= MONSTER_REACH &&
        (mob.z - z - 0.5).abs <= MONSTER_REACH && (mob.y - y).abs <= MONSTER_HEIGHT
    end
  end
end
