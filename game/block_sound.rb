# The sound of a block when the player or a mob digs it, breaks it, steps on
# it and places it. Each block has a sound class (STONE, WOOD and so on), and
# each class has one sound for each of these four. They follow VoxeLibre
# (mcl_sounds), but stone, wood and dirt break with one sound.
module BlockSound
  STONE = 0
  WOOD = 1
  DIRT = 2
  GRASS = 3
  SAND = 4
  GRAVEL = 5
  GLASS = 6
  LEAVES = 7
  CLOTH = 8
  SNOW = 9
  DIG = [Sfx::DIG_STONE, Sfx::DIG_WOOD, Sfx::DIG_SOFT, Sfx::DIG_SOFT, Sfx::DIG_SOFT, Sfx::DIG_GRAVEL, Sfx::DIG_STONE, Sfx::DIG_LEAVES,
         Sfx::CLOTH, Sfx::SNOW]
  BREAK = [Sfx::BREAK, Sfx::BREAK, Sfx::BREAK, Sfx::BREAK, Sfx::STEP_SAND, Sfx::BREAK_GRAVEL, Sfx::BREAK_GLASS, Sfx::STEP_GRASS,
           Sfx::CLOTH, Sfx::SNOW]
  STEP = [Sfx::STEP_HARD, Sfx::STEP_WOOD, Sfx::STEP_DIRT, Sfx::STEP_GRASS, Sfx::STEP_SAND, Sfx::STEP_GRAVEL, Sfx::STEP_GLASS, Sfx::STEP_GRASS,
          Sfx::CLOTH, Sfx::SNOW]
  PLACE = [Sfx::PLACE_HARD, Sfx::PLACE_HARD, Sfx::PLACE, Sfx::PLACE, Sfx::PLACE, Sfx::PLACE, Sfx::PLACE_HARD, Sfx::PLACE,
           Sfx::CLOTH, Sfx::PLACE]

  def self.dig(block) = DIG[of(block)]

  def self.broken(block) = BREAK[of(block)]

  def self.footstep(block) = STEP[of(block)]

  def self.placed(block) = PLACE[of(block)]

  # The sound class of block.
  def self.of(block)
    block = Block::BASE[block]
    return GLASS if block == Block::GLASS
    return GRAVEL if block == Block::GRAVEL
    return SAND if block == Block::SAND
    return GRASS if grassy?(block)
    return SNOW if block == Block::SNOW
    return CLOTH if block == Block::WOOL
    return WOOD if plant_wood?(block)
    return LEAVES if Block.leaves?(block) || Block.plant?(block)
    return STONE if stony?(block)
    return WOOD if wooden?(block)

    DIRT
  end

  def self.grassy?(block) = block == Block::GRASS || block == Block::SNOW_GRASS

  # A torch, a cactus and a pumpkin sound like wood.
  def self.plant_wood?(block) = block == Block::TORCH || block == Block::CACTUS || Block.pumpkin?(block)

  def self.stony?(block) = Block::NEEDS_PICK[block] > 0 || block == Block::BEDROCK

  def self.wooden?(block)
    Block.log?(block) || Block.planks?(block) || block == Block::CHEST || block == Block::BED || block == Block::DOOR ||
      block == Block::CRAFTING_TABLE || block == Block::LADDER
  end
end
