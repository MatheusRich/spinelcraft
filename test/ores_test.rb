require_relative "test_helper"

class OresTest < Minitest::Test
  ORES = [Block::COAL_ORE, Block::IRON, Block::DIAMOND, Block::SPINEL_ORE].freeze

  def test_the_layers_below_the_sea_each_stand_for_2_layers_of_minecraft
    assert_equal Ores::MC_BOTTOM, Ores.mc_y(1)
    assert_equal Ores::MC_BOTTOM + 2, Ores.mc_y(2)
    assert_equal Ores::MC_SEA - 2, Ores.mc_y(SEA - 1)
    assert_equal Ores::MC_SEA, Ores.mc_y(SEA)
    assert_equal Ores::MC_SEA + 1, Ores.mc_y(SEA + 1)
  end

  # So the ore of a column is that of a column of Minecraft from its
  # bottom to the y of the top layer here.
  def test_a_column_holds_as_much_of_each_ore_as_in_minecraft
    ORES.each do |ore|
      here = (1...WY).sum { |y| Ores.ore_at(ore, y) }
      there = (Ores::MC_BOTTOM..Ores.mc_y(WY - 1)).sum { |m| Ores.mc_ore(ore, m) }
      assert_in_delta there, here, 1e-9
    end
  end

  # minecraft.wiki/w/Ore_(feature) gives the veins of each chunk.
  def test_the_ore_of_a_chunk_is_its_veins_times_their_blocks
    total = ->(ore) { (-200..500).sum { |m| Ores.mc_ore(ore, m) } }
    assert_in_delta 50 * Ores::VEIN_17, total.(Block::COAL_ORE), 1e-9
    assert_in_delta 100 * Ores::VEIN_9 + 10 * Ores::VEIN_4, total.(Block::IRON), 1e-9
    assert_in_delta 7 * Ores::VEIN_4 + 6 * Ores::VEIN_8 + Ores::VEIN_12 / 9, total.(Block::DIAMOND), 1e-9
    assert_in_delta 4.5 * Ores::VEIN_9, total.(Block::SPINEL_ORE), 1e-9
  end

  # minecraft.wiki/w/Ore lists the layers with none of each ore.
  def test_each_ore_lies_in_its_layers_of_minecraft
    assert_equal 0.0, Ores.mc_ore(Block::COAL_ORE, -1)
    assert_operator Ores.mc_ore(Block::COAL_ORE, 1), :>, 0.0
    assert_equal 0.0, Ores.mc_ore(Block::COAL_ORE, 321)
    assert_operator Ores.mc_ore(Block::COAL_ORE, 320), :>, 0.0
    assert_operator Ores.mc_ore(Block::IRON, 72), :>, 0.0
    assert((73..80).all? { |m| Ores.mc_ore(Block::IRON, m) == 0.0 })
    assert_operator Ores.mc_ore(Block::IRON, 81), :>, 0.0
    assert_equal 0.0, Ores.mc_ore(Block::IRON, -65)
    assert_operator Ores.mc_ore(Block::DIAMOND, 15), :>, 0.0
    assert_equal 0.0, Ores.mc_ore(Block::DIAMOND, 16)
    assert_operator Ores.mc_ore(Block::SPINEL_ORE, 31), :>, 0.0
    assert_equal 0.0, Ores.mc_ore(Block::SPINEL_ORE, 32)
    assert_operator Ores.mc_ore(Block::SPINEL_ORE, -64), :>, 0.0
    assert_equal 0.0, Ores.mc_ore(Block::SPINEL_ORE, -65)
  end

  # A layer holds the veins that start at it, times their blocks. In a
  # triangle from y low to high, the peak layer gets 2 / (high - low) of
  # the veins. In an even spread, each layer gets 1 / (high - low + 1).
  # minecraft.wiki/w/Coal_Ore, /w/Iron_Ore, /w/Diamond_Ore and
  # /w/Gold_Ore (which spinel copies) give the veins and the spreads.
  def test_each_layer_of_minecraft_holds_the_veins_that_start_at_it
    coal = Ores::VEIN_17
    assert_in_delta coal * 20 * 2 / 192, Ores.mc_ore(Block::COAL_ORE, 96), 1e-9
    assert_in_delta coal * 20 * 2 / 192 * 57 / 96, Ores.mc_ore(Block::COAL_ORE, 135), 1e-9
    assert_in_delta coal * (20 * 2.0 / 192 * 56 / 96 + 30 / 185.0), Ores.mc_ore(Block::COAL_ORE, 136), 1e-9
    assert_in_delta coal * 30 / 185, Ores.mc_ore(Block::COAL_ORE, 193), 1e-9
    iron = Ores::VEIN_9
    small = Ores::VEIN_4 * 10 / 137
    assert_in_delta small, Ores.mc_ore(Block::IRON, -64), 1e-9
    assert_in_delta iron * 10 * 2 / 80 * 2 / 40 + small, Ores.mc_ore(Block::IRON, -22), 1e-9
    assert_in_delta iron * 10 * 2 / 80 + small, Ores.mc_ore(Block::IRON, 16), 1e-9
    assert_in_delta iron * 10 * 2 / 80 * 2 / 40 + small, Ores.mc_ore(Block::IRON, 54), 1e-9
    assert_in_delta iron * 90 * 2 / 304, Ores.mc_ore(Block::IRON, 232), 1e-9
    veins = 7 * Ores::VEIN_4 + 4 * Ores::VEIN_8 + Ores::VEIN_12 / 9
    medium = 2 * Ores::VEIN_8 / 61
    assert_in_delta veins * 2 / 160 + medium, Ores.mc_ore(Block::DIAMOND, -64), 1e-9
    assert_in_delta veins * 2 / 160 * 20 / 80 + medium, Ores.mc_ore(Block::DIAMOND, -4), 1e-9
    assert_in_delta veins * 2 / 160 * 19 / 80, Ores.mc_ore(Block::DIAMOND, -3), 1e-9
    spinel = Ores::VEIN_9 * 4 * 2 / 96
    lower = Ores::VEIN_9 * 0.5 / 17
    assert_in_delta lower, Ores.mc_ore(Block::SPINEL_ORE, -64), 1e-9
    assert_in_delta spinel * 16 / 48 + lower, Ores.mc_ore(Block::SPINEL_ORE, -48), 1e-9
    assert_in_delta spinel * 17 / 48, Ores.mc_ore(Block::SPINEL_ORE, -47), 1e-9
    assert_in_delta spinel, Ores.mc_ore(Block::SPINEL_ORE, -16), 1e-9
  end

  # 1 block of ore in each layer of a chunk takes 1 full cell in 256
  # columns, and twice as many cells when each holds half its blocks.
  def test_the_odds_of_a_clump_give_the_blocks_of_each_layer
    assert_equal 256, Ores.ore_odds(1.0, 8, 8.0)
    assert_equal 512, Ores.ore_odds(1.0, 8, 4.0)
    assert_equal 1024, Ores.ore_odds(2.0, 32, 16.0)
  end

  # A cell is coal when its coal roll is under the coal odds of its layer.
  # Else its other roll picks iron at the bottom of its range, diamond
  # just above iron, and spinel at the top. Layer 35 has all four ores.
  def test_the_rolls_of_a_cell_pick_its_ore_at_the_odds_of_its_layer
    ores = Ores.new
    y = 35
    coal = odds(Block::COAL_ORE, y, Ores::COAL_CELL, Ores::VEIN_17)
    iron = odds(Block::IRON, y, Ores::ORE_CELL, Ores::VEIN_9)
    diamond = odds(Block::DIAMOND, y, Ores::ORE_CELL, Ores::DIAMOND_VEIN)
    spinel = odds(Block::SPINEL_ORE, y, Ores::ORE_CELL, Ores::VEIN_9)
    assert [coal, iron, diamond, spinel].all?(&:positive?)
    assert_operator iron + diamond, :<, 65535 - spinel
    assert_equal Block::COAL_ORE, ores.clump(y, coal - 1, 0)
    assert_equal Block::IRON, ores.clump(y, coal, iron - 1)
    assert_equal Block::DIAMOND, ores.clump(y, coal, iron)
    assert_equal Block::DIAMOND, ores.clump(y, coal, iron + diamond - 1)
    assert_equal Block::STONE, ores.clump(y, coal, iron + diamond)
    assert_equal Block::STONE, ores.clump(y, coal, 65535 - spinel)
    assert_equal Block::SPINEL_ORE, ores.clump(y, coal, 65536 - spinel)
  end

  private

  def odds(ore, y, cell, vein) = Ores.ore_odds(Ores.ore_at(ore, y), cell, vein)
end
