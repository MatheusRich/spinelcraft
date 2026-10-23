# The breeding of the animals. Each adult in love mode walks to the
# nearest adult of its kind in love mode, and two mates near each other
# make a baby. The Love of each animal holds its own state; Breeding pairs
# the lovers among all the mobs. minecraft.wiki/w/Breeding
class Breeding
  def initialize(seed)
    @rng = Rng.new(seed)
  end

  # Pairs the lovers among mobs for this frame. Each lover walks to its
  # nearest mate within Love::MATE_REACH. Two mates that walked to each
  # other for Love::COURT_TIME and are nearer than Love::MATE_NEAR make a
  # baby, which goes into mobs, and particles shows their hearts.
  def pair_lovers(mobs, particles)
    count = mobs.size
    index = 0
    while index < count
      lover = mobs[index]
      in_love = lover.passive? && lover.love.on?
      mate_index = in_love ? nearest_mate(mobs, index) : -1
      index += 1
      next unless in_love

      if mate_index < 0
        lover.love.alone
        next
      end
      mate = mobs[mate_index]
      lover.love.court(mate.x.to_f, mate.z.to_f)
      dx = (mate.x - lover.x).to_f
      dz = (mate.z - lover.z).to_f
      breed(mobs, lover, mate, particles) if lover.love.court_time >= Love::COURT_TIME && dx * dx + dz * dz < Love::MATE_NEAR * Love::MATE_NEAR
    end
    # A nil return keeps Spinel from boxing the loop.
    nil
  end

  # The index in mobs of the nearest other adult of the kind of the mob at
  # lover_index in love mode, within Love::MATE_REACH, or -1.
  def nearest_mate(mobs, lover_index)
    lover = mobs[lover_index]
    best = -1
    nearest_squared = Love::MATE_REACH * Love::MATE_REACH
    index = 0
    while index < mobs.size
      other = mobs[index]
      if index != lover_index && other.kind == lover.kind && other.love.on? && !other.dying?
        # to_f: Spinel cannot type the positions of the mobs.
        dx = (other.x - lover.x).to_f
        dy = (other.y - lover.y).to_f
        dz = (other.z - lover.z).to_f
        squared = dx * dx + dy * dy + dz * dz
        if squared < nearest_squared
          best = index
          nearest_squared = squared
        end
      end
      index += 1
    end
    best
  end

  # Two mates make one baby of their kind where the first one stands. Both
  # show a burst of hearts, as in Minecraft since 1.15.
  def breed(mobs, first, second, particles)
    first.love.bred
    second.love.bred
    baby = Animal.new(first.kind, first.x, first.y, first.z, (@rng.rand01 * 100000.0).to_i)
    baby.make_baby
    mobs << baby
    # to_f: Spinel cannot type the mobs, and the particles need Floats.
    particles.hearts(first.x.to_f, first.y.to_f, first.z.to_f, first.half.to_f, first.tall.to_f)
    particles.hearts(second.x.to_f, second.y.to_f, second.z.to_f, second.half.to_f, second.tall.to_f)
  end
end
