require_relative "test_helper"

class LightningTest < Minitest::Test
  def setup
    @lightning = Lightning.new(3)
  end

  def strike
    @lightning.strike(10, 60, 20, 10.5, 61.0, 20.5)
  end

  def test_a_new_lightning_shows_nothing
    refute @lightning.visible?
    assert_equal 0.0, @lightning.flash
  end

  def test_a_strike_shows_the_bolt_and_flashes
    strike
    assert @lightning.visible?
    assert_equal 1.0, @lightning.flash
    assert_equal [10, 60, 20], [@lightning.x, @lightning.y, @lightning.z]
  end

  def test_the_bolt_goes_from_the_clouds_to_the_ground_cell
    strike
    mesh = Mesh3.new
    @lightning.draw(mesh, 0.0, 70.0, 0.0)
    ys = mesh.v.each_slice(11).map { |vertex| vertex[1] }
    assert_in_delta Clouds::HEIGHT, ys.max, Lightning::GLOW
    assert_in_delta 60.0, ys.min, Lightning::GLOW
  end

  def test_a_bolt_that_ends_above_the_clouds_still_comes_from_above
    @lightning.strike(5, 201, 5, 5.5, 202.0, 5.5)
    mesh = Mesh3.new
    @lightning.draw(mesh, 0.0, 230.0, 0.0)
    ys = mesh.v.each_slice(11).map { |vertex| vertex[1] }
    assert_in_delta 201.0, ys.min, Lightning::GLOW
    assert_in_delta 201.0 + Lightning::MIN_HEIGHT, ys.max, Lightning::GLOW
  end

  def test_the_flash_fades_after_the_bolt
    strike
    @lightning.update_lightning(Lightning::LIFE + Lightning::FLASH_FADE / 2.0)
    refute @lightning.visible?
    assert_operator @lightning.flash, :>, 0.0
    assert_operator @lightning.flash, :<, Lightning::FLASH_AFTER
    @lightning.update_lightning(Lightning::FLASH_FADE)
    assert_equal 0.0, @lightning.flash
  end

  def test_the_bolt_flickers_dark_once_each_four_ticks
    strike
    @lightning.update_lightning(2.0 / Lightning::TICKS_PER_SECOND + 0.001)
    assert_equal Lightning::FLASH_DARK, @lightning.flash
    mesh = Mesh3.new
    @lightning.draw(mesh, 0.0, 70.0, 0.0)
    assert_empty mesh.v
  end

  def test_the_thunder_takes_the_distance_over_the_speed_of_sound
    @lightning.strike(10, 60, 20, 10.5 + Lightning::SOUND_SPEED, 60.0, 20.5)
    refute @lightning.thunder_arrived?(0.99)
    assert @lightning.thunder_arrived?(0.02)
    assert_equal 10.5, @lightning.heard_x
    refute @lightning.thunder_arrived?(10.0)
  end

  def test_two_strikes_bring_two_thunders
    strike
    strike
    assert @lightning.thunder_arrived?(1.0)
    assert @lightning.thunder_arrived?(0.0)
    refute @lightning.thunder_arrived?(1.0)
  end
end
