require_relative "test_helper"

class BiomeTest < Minitest::Test
  TEMPERATE = 0.0
  WARM = 0.5
  COOL = -0.2
  COLD = -0.5

  def test_each_climate_has_a_biome_for_each_landform_and_humidity
    assert_equal Biome::CLIMATES.size, Biome::BIOMES.size
    assert_equal Biome::CLIMATES.size, Biome::CLIMATE_STARTS.size + 1
    assert(Biome::BIOMES.all? { |climate| climate.size == Biome::LANDFORMS.size })
    assert(Biome::BIOMES.flatten(1).all? { |humidities| humidities.size == Biome::HUMIDITIES.size })
  end

  def test_each_climate_starts_at_its_temperature
    Biome::CLIMATE_STARTS.each_with_index do |start, index|
      climate = index + 1
      assert_equal Biome::BIOMES[climate][Biome::ROUGH][Biome::MOIST], Biome.pick(start, 0.0, Biome::ROUGH)
      assert_equal Biome::BIOMES[index][Biome::ROUGH][Biome::MOIST], Biome.pick(start - 0.001, 0.0, Biome::ROUGH)
    end
  end

  def test_rough_land_grows_forests_and_taigas_at_any_humidity
    [-0.5, 0.0, 0.5].each do |humidity|
      assert_equal Biome::FOREST, Biome.pick(TEMPERATE, humidity, Biome::ROUGH)
      assert_equal Biome::TAIGA, Biome.pick(COOL, humidity, Biome::ROUGH)
      assert_equal Biome::SNOWY_TAIGA, Biome.pick(COLD, humidity, Biome::ROUGH)
    end
  end

  def test_flat_land_grows_plains_and_deserts_at_any_humidity
    [-0.5, 0.0, 0.5].each do |humidity|
      assert_equal Biome::PLAINS, Biome.pick(TEMPERATE, humidity, Biome::FLAT)
      assert_equal Biome::DESERT, Biome.pick(WARM, humidity, Biome::FLAT)
      assert_equal Biome::TUNDRA, Biome.pick(COLD, humidity, Biome::FLAT)
    end
  end

  def test_swamps_grow_only_on_wet_low_land
    wet = Biome::WET_ABOVE[Biome::TEMPERATE] + 0.01
    assert_equal Biome::SWAMP, Biome.pick(TEMPERATE, wet, Biome::LOW)
    refute_equal Biome::SWAMP, Biome.pick(TEMPERATE, wet - 0.02, Biome::LOW)
    (Biome::LANDFORMS - [Biome::LOW]).each do |landform|
      refute_equal Biome::SWAMP, Biome.pick(TEMPERATE, wet, landform)
    end
  end

  def test_the_humidity_picks_the_biome_on_the_land_between
    assert_equal Biome::PLAINS, Biome.pick(TEMPERATE, Biome::DRY_BELOW[Biome::TEMPERATE] - 0.01, Biome::MIDDLE)
    assert_equal Biome::FOREST, Biome.pick(TEMPERATE, Biome::DRY_BELOW[Biome::TEMPERATE], Biome::MIDDLE)
    assert_equal Biome::DESERT, Biome.pick(WARM, -0.5, Biome::MIDDLE)
    assert_equal Biome::SAVANNA, Biome.pick(WARM, 0.0, Biome::MIDDLE)
    assert_equal Biome::JUNGLE, Biome.pick(WARM, Biome::WET_ABOVE[Biome::WARM] + 0.01, Biome::MIDDLE)
    assert_equal Biome::SAVANNA, Biome.pick(WARM, Biome::WET_ABOVE[Biome::WARM], Biome::MIDDLE)
  end

  def test_plateau_tops_grow_plains_and_savannas
    assert_equal Biome::PLAINS, Biome.pick(TEMPERATE, 0.5, Biome::PLATEAU)
    assert_equal Biome::SAVANNA, Biome.pick(WARM, 0.5, Biome::PLATEAU)
  end

  def test_the_erosion_and_the_height_pick_the_landform
    rough = Terrain::ROUGH_EROSION - 0.001
    flat = Terrain::FLAT_EROSION + 0.001
    plateau = (Terrain::PLATEAU_LOW_EROSION + Terrain::PLATEAU_HIGH_EROSION) / 2
    middle = Terrain::FLAT_EROSION - 0.001
    top = SEA + Terrain::PLATEAU_TOP
    assert_equal Biome::ROUGH, Terrain.landform(rough, Terrain::SWAMP_TOP)
    assert_equal Biome::LOW, Terrain.landform(Terrain::ROUGH_EROSION, Terrain::SWAMP_TOP)
    assert_equal Biome::LOW, Terrain.landform(flat, Terrain::SWAMP_TOP)
    assert_equal Biome::FLAT, Terrain.landform(flat, Terrain::SWAMP_TOP + 1)
    assert_equal Biome::MIDDLE, Terrain.landform(Terrain::FLAT_EROSION, Terrain::SWAMP_TOP + 1)
    assert_equal Biome::PLATEAU, Terrain.landform(plateau, top)
    assert_equal Biome::PLATEAU, Terrain.landform(Terrain::PLATEAU_LOW_EROSION, top)
    assert_equal Biome::PLATEAU, Terrain.landform(Terrain::PLATEAU_HIGH_EROSION, top)
    assert_equal Biome::MIDDLE, Terrain.landform(plateau, top - 1)
    assert_equal Biome::MIDDLE, Terrain.landform(Terrain::PLATEAU_HIGH_EROSION + 0.001, top)
    assert_equal Biome::MIDDLE, Terrain.landform(middle, top)
  end
end
