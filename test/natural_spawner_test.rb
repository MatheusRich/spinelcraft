require_relative "test_helper"

class NaturalSpawnerTest < Minitest::Test
  # A cell high in the open air of the middle chunk.
  X = 8
  Y = SKY_Y
  Z = 8

  # A world of 5 x 5 chunks with a floor of grass under SKY_Y, for the
  # animal spawns. The tests do not change it, so they share it.
  def self.grass_world
    @grass_world ||= begin
      world = World.new(1337)
      (-2..2).each { |cx| (-2..2).each { |cz| world.load_chunk(cx, cz) } }
      (-32..47).each { |x| (-32..47).each { |z| world.set(x, SKY_Y - 1, z, Block::GRASS) } }
      world
    end
  end

  def setup
    @world = World.new(1337)
    (-1..1).each { |cx| (-1..1).each { |cz| @world.load_chunk(cx, cz) } }
    @spawner = NaturalSpawner.new(@world, 5, false)
    # The middle of the chunk to the -x side of the world: the loaded cells
    # are 14 to 62 blocks away along x.
    @player = Player.new(-30.0, 75.0, 8.0)
  end

  def test_monsters_spawn_up_to_the_cap_and_animals_do_not_count
    mobs = Array.new(30) { Animal.new(Mob::PIG, 0.0, 0.0, 0.0, 1) }
    @spawner.spawn_monsters(mobs, @player, 0, 10.0)
    assert_equal 30 + NaturalSpawner::MONSTER_CAP, mobs.size
    assert_equal 30, mobs.count(&:passive?)
  end

  def test_no_monster_spawns_when_the_monsters_fill_the_cap
    mobs = Array.new(NaturalSpawner::MONSTER_CAP) { Monster.new(Mob::ZOMBIE, 0.0, 0.0, 0.0, 1) }
    @spawner.spawn_monsters(mobs, @player, 0, 10.0)
    assert_equal NaturalSpawner::MONSTER_CAP, mobs.size
  end

  def test_monsters_spawn_with_time
    mobs = []
    @spawner.spawn_monsters(mobs, @player, 0, 0.0)
    assert_empty mobs
    @spawner.spawn_monsters(mobs, @player, 0, 0.5)
    refute_empty mobs
    # One tick has about 9 pack centers in the loaded chunks, and most of
    # them are in the ground.
    mobs.clear
    @spawner.spawn_monsters(mobs, @player, 0, 1.0 / 20.0)
    assert_operator mobs.size, :<, NaturalSpawner::PACK_SIZE * 3
  end

  def test_the_last_monster_under_the_cap_spawns_alone
    [24, 23, 12].each do |monsters|
      mobs = Array.new(monsters) { Monster.new(Mob::ZOMBIE, 0.0, 0.0, 0.0, 1) }
      @spawner.spawn_monsters(mobs, @player, 0, 10.0)
      assert_equal NaturalSpawner::MONSTER_CAP, mobs.size
    end
  end

  def test_a_pack_center_spawns_at_most_4_monsters_and_no_more_than_the_room
    # A cave with a floor across the chunks, where most steps of a pack
    # fit a monster. Only 9 of the 17 x 17 chunks are loaded, and 1 height
    # in about 75 is the cave, so few of the centers are in it.
    layer(9, Block::STONE)
    layer(10, Block::AIR)
    layer(11, Block::AIR)
    mobs = []
    spawned = Array.new(50_000) { @spawner.spawn_packs(mobs, @player, 0, NaturalSpawner::MONSTER_CAP) }
    assert_equal NaturalSpawner::PACK_SIZE, spawned.max
    assert_equal mobs.size, spawned.sum
    spawned = Array.new(50_000) { @spawner.spawn_packs(mobs, @player, 0, 1) }
    assert_equal 1, spawned.max
  end

  def test_monsters_spawn_around_the_player_far_from_the_origin
    world = World.new(1337)
    (40..42).each { |cx| (40..42).each { |cz| world.load_chunk(cx, cz) } }
    mobs = []
    player = Player.new(39 * 16 + 8.0, 75.0, 41 * 16 + 8.0)
    NaturalSpawner.new(world, 5, false).spawn_monsters(mobs, player, 0, 10.0)
    assert_equal NaturalSpawner::MONSTER_CAP, mobs.size
  end

  def test_a_monster_spawns_on_solid_ground_with_room_for_its_body_away_from_the_player
    mobs = []
    @spawner.spawn_monsters(mobs, @player, 0, 10.0)
    mobs.each do |monster|
      assert_includes NaturalSpawner::MONSTER_KINDS, monster.kind
      x = monster.x.floor
      y = monster.y.floor
      z = monster.z.floor
      assert Block.solid?(@world.get(x, y - 1, z))
      assert_equal Block::AIR, @world.get(x, y, z)
      assert_equal Block::AIR, @world.get(x, y + 1, z)
      distance = Math.sqrt((monster.x - @player.x)**2 + (monster.y - 0.01 - @player.y)**2 + (monster.z - @player.z)**2)
      assert_operator distance, :>=, NaturalSpawner::SPAWN_NEAR
    end
  end

  def test_monsters_spawn_in_packs_of_one_kind
    mobs = []
    @spawner.spawn_monsters(mobs, @player, 0, 10.0)
    kinds = mobs.map(&:kind).uniq
    assert_equal NaturalSpawner::MONSTER_KINDS.sort, kinds.sort
    # Most monsters stand next to one of the same kind.
    packed = mobs.count do |monster|
      mobs.any? { |other| !other.equal?(monster) && other.kind == monster.kind && (other.x - monster.x).abs <= 10.0 && (other.z - monster.z).abs <= 10.0 }
    end
    assert_operator packed, :>, mobs.size / 2
  end

  def test_a_monster_fits_on_solid_ground_with_two_free_cells
    player = Player.new(X + 0.5, Y.to_f, Z + 40.5)
    floor
    assert @spawner.monster_fits?(player, X, Y, Z, 0)
    @world.set(X, Y - 1, Z, Block::OAK_LEAVES)
    refute @spawner.monster_fits?(player, X, Y, Z, 0)
    @world.set(X, Y - 1, Z, Block::AIR)
    refute @spawner.monster_fits?(player, X, Y, Z, 0)
    floor
    @world.set(X, Y + 1, Z, Block::STONE)
    refute @spawner.monster_fits?(player, X, Y, Z, 0)
    @world.set(X, Y + 1, Z, Block::AIR)
    @world.set(X, Y, Z, Block::TALL_GRASS)
    refute @spawner.monster_fits?(player, X, Y, Z, 0)
  end

  def test_a_monster_fits_from_24_blocks_to_128_blocks_away_from_the_player
    floor
    assert @spawner.monster_fits?(Player.new(X + 0.5, Y.to_f, Z + 24.5), X, Y, Z, 0)
    refute @spawner.monster_fits?(Player.new(X + 0.5, Y.to_f, Z + 24.0), X, Y, Z, 0)
    assert @spawner.monster_fits?(Player.new(X + 0.5, Y - 128.0, Z + 0.5), X, Y, Z, 0)
    refute @spawner.monster_fits?(Player.new(X + 0.5, Y - 128.5, Z + 0.5), X, Y, Z, 0)
    refute @spawner.monster_fits?(Player.new(X + 24.4, Y.to_f, Z + 0.5), X, Y, Z, 0)
  end

  def test_no_monster_fits_out_of_the_loaded_chunks_or_at_the_bottom_of_the_world
    floor
    # The chunk WX blocks away along x has the same place in the ring of
    # loaded chunks as this chunk, but it is not loaded.
    assert @spawner.monster_fits?(Player.new(X + 0.5, Y.to_f, Z + 40.5), X, Y, Z, 0)
    refute @spawner.monster_fits?(Player.new(X + WX + 0.5, Y.to_f, Z + 40.5), X + WX, Y, Z, 0)
    @world.set(X, 0, Z, Block::BEDROCK)
    @world.set(X, 1, Z, Block::AIR)
    @world.set(X, 2, Z, Block::AIR)
    @world.set(X, 3, Z, Block::STONE)
    refute @spawner.monster_fits?(Player.new(X + 0.5, 1.0, Z + 30.5), X, 0, Z, 15)
    assert @spawner.monster_fits?(Player.new(X + 0.5, 1.0, Z + 30.5), X, 1, Z, 15)
  end

  def test_a_cell_under_the_open_sky_is_never_dark_by_day_and_half_of_the_time_at_night
    floor
    assert_equal 0, dark_tries(15, 200)
    assert_equal 200, dark_tries(0, 200)
    # At sky light 4, a random number from 0 to 7 lets half the tries pass.
    assert_in_delta 200, dark_tries(4, 400), 50
    assert_equal 0, dark_tries(8, 200)
    assert_operator dark_tries(7, 400), :>, 20
  end

  def test_a_closed_cell_is_dark_by_day
    floor
    [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, 0, 1], [0, 0, -1]].each { |dx, dy, dz| @world.set(X + dx, Y + dy, Z + dz, Block::STONE) }
    assert_equal 200, dark_tries(15, 200)
  end

  def test_a_cell_in_the_light_of_a_torch_is_never_dark
    floor
    # The torch gives the cell light 4, which is less than the random
    # number half of the time. A monster needs block light 0.
    @world.set(X + 10, Y, Z, Block::TORCH)
    assert_equal 0, dark_tries(0, 200)
  end

  def test_on_halloween_a_zombie_or_a_skeleton_wears_a_pumpkin_now_and_then
    spawner = NaturalSpawner.new(@world, 5, true)
    heads = Hash.new(0)
    4000.times { heads[spawner.halloween_head(Mob::ZOMBIE)] += 1 }
    assert_in_delta 900, heads[Block::CARVED_PUMPKIN], 120
    assert_in_delta 100, heads[Block::JACK_O_LANTERN], 45
    assert_equal [0, Block::CARVED_PUMPKIN, Block::JACK_O_LANTERN].sort, heads.keys.sort
    assert(200.times.any? { spawner.halloween_head(Mob::SKELETON) == Block::CARVED_PUMPKIN })
    assert(200.times.any? { spawner.halloween_head(Mob::SKELETON) == Block::JACK_O_LANTERN })
    assert(200.times.all? { spawner.halloween_head(Mob::CREEPER) == 0 })
  end

  def test_no_monster_wears_a_pumpkin_on_other_days
    assert(200.times.all? { @spawner.halloween_head(Mob::ZOMBIE) == 0 })
    mobs = []
    @spawner.spawn_monsters(mobs, @player, 0, 10.0)
    assert(mobs.all? { |monster| monster.head == 0 })
  end

  def test_on_halloween_the_new_monsters_wear_pumpkins
    spawner = NaturalSpawner.new(@world, 5, true)
    mobs = []
    spawner.spawn_monsters(mobs, @player, 0, 10.0)
    assert(mobs.any? { |monster| monster.head != 0 })
  end

  def test_animals_spawn_on_grass_around_the_player
    world = self.class.grass_world
    player = Player.new(8.0, SKY_Y.to_f, 8.0)
    mobs = []
    NaturalSpawner.new(world, 5, false).spawn_animals(mobs, player)
    assert_operator mobs.size, :>, NaturalSpawner::ANIMALS / 2
    assert_operator mobs.size, :<=, NaturalSpawner::ANIMALS
    mobs.each do |animal|
      assert_includes NaturalSpawner::ANIMAL_KINDS, animal.kind
      assert_equal SKY_Y + 0.01, animal.y
      assert_equal 0.5, animal.x - animal.x.floor
      assert_equal 0.5, animal.z - animal.z.floor
      distance = Math.sqrt((animal.x - player.x)**2 + (animal.z - player.z)**2)
      assert_operator distance, :>=, 10.0 - 1.0
    end
    assert_equal NaturalSpawner::ANIMAL_KINDS.sort, mobs.map(&:kind).uniq.sort
    # The animals stand on each side of the player, near and far.
    assert(mobs.any? { |animal| animal.x < player.x - 10.0 } && mobs.any? { |animal| animal.x > player.x + 10.0 })
    assert(mobs.any? { |animal| animal.z < player.z - 10.0 } && mobs.any? { |animal| animal.z > player.z + 10.0 })
    assert(mobs.any? { |animal| Math.sqrt((animal.x - player.x)**2 + (animal.z - player.z)**2) > 25.0 })
  end

  def test_no_animal_spawns_out_of_the_loaded_chunks
    # The chunks WX blocks away along x have the same places in the ring
    # of loaded chunks as the chunks of the grass world, but they are not
    # loaded.
    mobs = []
    NaturalSpawner.new(self.class.grass_world, 5, false).spawn_animals(mobs, Player.new(8.0 + WX, SKY_Y.to_f, 8.0))
    assert_empty mobs
  end

  def test_an_animal_spawns_only_on_grass_with_room_for_its_body
    player = Player.new(X.to_f, SKY_Y.to_f, Z.to_f)
    layer(SKY_Y - 1, Block::STONE)
    assert_empty animals_around(player)
    layer(SKY_Y - 1, Block::GRASS)
    # Glass does not block light, so the grass stays the ground.
    layer(SKY_Y + 1, Block::GLASS)
    assert_empty animals_around(player)
    layer(SKY_Y + 1, Block::AIR)
    layer(SKY_Y, Block::TALL_GRASS)
    assert_empty animals_around(player)
    layer(SKY_Y, Block::AIR)
    refute_empty animals_around(player)
    layer(SKY_Y - 1, Block::SNOW_GRASS)
    refute_empty animals_around(player)
  end

  def test_an_animal_stands_in_the_middle_of_its_grass_cell
    (-16..31).each { |x| (-16..31).each { |z| @world.set(x, SKY_Y - 1, z, (x + z).even? ? Block::GRASS : Block::STONE) } }
    animals = animals_around(Player.new(X.to_f, SKY_Y.to_f, Z.to_f))
    refute_empty animals
    animals.each do |animal|
      assert_equal Block::GRASS, @world.get(animal.x.floor, SKY_Y - 1, animal.z.floor)
      assert_equal 0.5, animal.x - animal.x.floor
      assert_equal 0.5, animal.z - animal.z.floor
    end
  end

  def test_an_animal_spawns_from_near_to_far_blocks_away
    player = Player.new(8.0, SKY_Y.to_f, 8.0)
    spawner = NaturalSpawner.new(self.class.grass_world, 5, false)
    mobs = []
    50.times { spawner.spawn_animal(mobs, player, 10.0, 20.0) }
    assert_equal 50, mobs.size
    mobs.each do |animal|
      distance = Math.sqrt((animal.x - player.x)**2 + (animal.z - player.z)**2)
      assert_operator distance, :>=, 10.0 - 1.0
      assert_operator distance, :<, 20.0 + 1.0
    end
  end

  def test_one_animal_spawns_each_2_seconds_while_fewer_than_12_are_left
    world = self.class.grass_world
    spawner = NaturalSpawner.new(world, 5, false)
    player = Player.new(-50.0, SKY_Y.to_f, 8.0)
    mobs = Array.new(10) { Animal.new(Mob::PIG, 0.0, 0.0, 0.0, 1) } + Array.new(20) { Monster.new(Mob::ZOMBIE, 0.0, 0.0, 0.0, 1) }
    spawner.refill_animals(mobs, player, 0.0)
    assert_equal 31, mobs.size
    spawner.refill_animals(mobs, player, 1.0)
    assert_equal 31, mobs.size
    spawner.refill_animals(mobs, player, 1.0)
    assert_equal 32, mobs.size
    spawner.refill_animals(mobs, player, 2.0)
    assert_equal 32, mobs.size
    animal = mobs.last
    distance = Math.sqrt((animal.x - player.x)**2 + (animal.z - player.z)**2)
    assert_operator distance, :>=, 40.0 - 1.0
    assert_operator distance, :<, 90.0 + 1.0
  end

  def test_a_kind_comes_up_by_its_weight
    picks = Hash.new(0)
    4000.times { picks[@spawner.pick_kind([1, 2, 3], [1.0, 2.0, 1.0])] += 1 }
    assert_in_delta 1000, picks[1], 120
    assert_in_delta 2000, picks[2], 120
    assert_in_delta 1000, picks[3], 120
  end

  private

  # A stone floor under the cell X, Y, Z and its neighbors.
  def floor
    (-1..1).each { |dx| (-1..1).each { |dz| @world.set(X + dx, Y - 1, Z + dz, Block::STONE) } }
  end

  # Sets the cells at height y of the 3 x 3 chunks to block.
  def layer(y, block)
    (-16..31).each { |x| (-16..31).each { |z| @world.set(x, y, z, block) } }
  end

  # The animals that spawn_animals puts around player.
  def animals_around(player)
    mobs = []
    @spawner.spawn_animals(mobs, player)
    mobs
  end

  # How many of tries say that X, Y, Z is dark at sky light sky.
  def dark_tries(sky, tries)
    dark = 0
    tries.times { dark += 1 if @spawner.dark?(X, Y, Z, sky) }
    dark
  end
end
