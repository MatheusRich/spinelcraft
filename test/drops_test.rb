require_relative "test_helper"

# What a mob drops when it dies (Animal#drops, Monster#drops).
class DropsTest < Minitest::Test
  TRIES = 400

  def setup
    @rng = Rng.new(7)
  end

  def test_a_pig_drops_1_to_3_porkchops
    pig = animal(Mob::PIG)
    assert_equal [1, 2, 3], counts(pig, Block::PORKCHOP)
    assert_equal [0], counts(pig, Block::COOKED_PORKCHOP)
  end

  def test_a_pig_that_dies_on_fire_drops_cooked_porkchops
    pig = on_fire(animal(Mob::PIG))
    assert_equal [1, 2, 3], counts(pig, Block::COOKED_PORKCHOP)
    assert_equal [0], counts(pig, Block::PORKCHOP)
  end

  def test_a_cow_drops_0_to_2_leather_and_1_to_3_raw_beef
    cow = animal(Mob::COW)
    assert_equal [0, 1, 2], counts(cow, Block::LEATHER)
    assert_equal [1, 2, 3], counts(cow, Block::BEEF)
    assert_equal [0], counts(cow, Block::STEAK)
  end

  def test_a_cow_that_dies_on_fire_drops_steak
    cow = on_fire(animal(Mob::COW))
    assert_equal [1, 2, 3], counts(cow, Block::STEAK)
    assert_equal [0], counts(cow, Block::BEEF)
  end

  def test_a_chicken_drops_0_to_2_feathers_and_1_raw_chicken
    chicken = animal(Mob::CHICKEN)
    assert_equal [0, 1, 2], counts(chicken, Block::FEATHER)
    assert_equal [1], counts(chicken, Block::RAW_CHICKEN)
    assert_equal [0], counts(chicken, Block::COOKED_CHICKEN)
  end

  def test_a_chicken_that_dies_on_fire_drops_cooked_chicken
    chicken = on_fire(animal(Mob::CHICKEN))
    assert_equal [1], counts(chicken, Block::COOKED_CHICKEN)
    assert_equal [0], counts(chicken, Block::RAW_CHICKEN)
  end

  def test_a_sheep_drops_its_wool_and_1_to_2_mutton
    sheep = animal(Mob::SHEEP)
    assert_equal [1], counts(sheep, Block::WOOL)
    assert_equal [1, 2], counts(sheep, Block::MUTTON)
    assert_equal [0], counts(sheep, Block::COOKED_MUTTON)
  end

  def test_a_sheep_that_dies_on_fire_drops_cooked_mutton
    sheep = on_fire(animal(Mob::SHEEP))
    assert_equal [1], counts(sheep, Block::WOOL)
    assert_equal [1, 2], counts(sheep, Block::COOKED_MUTTON)
    assert_equal [0], counts(sheep, Block::MUTTON)
  end

  def test_a_sheared_sheep_drops_no_wool
    sheep = animal(Mob::SHEEP)
    sheep.sheared = true
    assert_equal [0], counts(sheep, Block::WOOL)
    assert_equal [1, 2], counts(sheep, Block::MUTTON)
  end

  def test_a_baby_drops_nothing
    [Mob::PIG, Mob::COW, Mob::CHICKEN, Mob::SHEEP].each do |kind|
      baby = animal(kind)
      baby.make_baby
      assert_empty baby.drops(@rng), Mob::NAMES[kind]
    end
  end

  def test_a_zombie_drops_0_to_2_rotten_flesh
    assert_equal [0, 1, 2], counts(monster(Mob::ZOMBIE), Block::ROTTEN_FLESH)
  end

  def test_a_skeleton_drops_0_to_2_arrows_and_bones
    skeleton = monster(Mob::SKELETON)
    assert_equal [0, 1, 2], counts(skeleton, Block::ARROW)
    assert_equal [0, 1, 2], counts(skeleton, Block::BONE)
  end

  # minecraft.wiki/w/Skeleton gives the bow a chance of 8.5%.
  def test_a_skeleton_that_the_player_kills_drops_its_bow_now_and_then
    skeleton = monster(Mob::SKELETON)
    skeleton.by_player = true
    bows = Array.new(TRIES) { count_of(skeleton.drops(@rng), Block::BOW) }
    assert_equal [0, 1], bows.uniq.sort
    assert_in_delta 0.085, bows.sum / TRIES.to_f, 0.04
  end

  def test_a_skeleton_that_dies_on_its_own_keeps_its_bow
    assert_equal [0], counts(monster(Mob::SKELETON), Block::BOW)
  end

  def test_a_creeper_drops_nothing
    assert_empty monster(Mob::CREEPER).drops(@rng)
  end

  private

  def animal(kind) = Animal.new(kind, 8.5, SKY_Y.to_f, 8.5, 3)

  def monster(kind) = Monster.new(kind, 8.5, SKY_Y.to_f, 8.5, 3)

  # The mob stands in lava for one step, which sets it on fire.
  def on_fire(mob)
    world = world_with_one_chunk
    world.set(8, SKY_Y, 8, Block::LAVA)
    mob.update_mob(world, 1.0 / 60.0, Player.new(2.5, SKY_Y.to_f, 2.5), Block::AIR)
    assert_predicate mob, :burning?
    mob
  end

  # The counts of block that the mob drops in TRIES deaths, each count once.
  def counts(mob, block) = Array.new(TRIES) { count_of(mob.drops(@rng), block) }.uniq.sort

  def count_of(drops, block)
    drops.each_slice(2).sum { |item, count| item == block ? count : 0 }
  end
end
