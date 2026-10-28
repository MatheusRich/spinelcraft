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

  # The floats of one vertex in a Mesh3: x y z, u v, layer, red green blue alpha, glow.
  def bolt_vertices(eye)
    strike
    mesh = Mesh3.new
    @lightning.draw(mesh, *eye)
    mesh.v.each_slice(11).to_a
  end

  def test_the_bolt_is_a_bright_white_core_in_a_wider_pale_glow
    vertices = bolt_vertices([0.0, 70.0, 0.0])
    core, glow = vertices.partition { |vertex| vertex[9] == 1.0 }
    assert_equal vertices.size / 2, core.size
    assert_equal [[1.0, 1.0, 1.0, 1.0]], core.map { |vertex| vertex[6, 4] }.uniq
    red, green, blue, alpha = glow.first[6, 4]
    assert_operator alpha, :<, 1.0
    assert_operator blue, :>, red
    assert_operator green, :>, red
    width = ->(strip) { Math.sqrt(3.times.sum { |axis| (strip[1][axis] - strip[0][axis])**2 }) }
    assert_in_delta Lightning::GLOW / Lightning::CORE, width.call(glow) / width.call(core), 1.0e-6
  end

  def test_a_strip_of_the_bolt_runs_along_its_line_and_turns_its_side_to_the_eye
    eye = [0.0, 70.0, 0.0]
    strip = bolt_vertices(eye).first(6).map { |vertex| vertex[0, 3] }
    subtract = ->(a, b) { a.zip(b).map { |x, y| x - y } }
    middle = ->(a, b) { a.zip(b).map { |x, y| (x + y) / 2.0 } }
    dot = ->(a, b) { a.zip(b).sum { |x, y| x * y } }
    start = middle.call(strip[0], strip[1])
    finish = middle.call(strip[5], strip[2])
    side = subtract.call(strip[1], strip[0])
    assert_in_delta 0.0, dot.call(side, subtract.call(finish, start)), 1.0e-6
    assert_in_delta 0.0, dot.call(side, subtract.call(middle.call(start, finish), eye)), 1.0e-6
    assert_equal strip[0], strip[3]
    assert_equal strip[2], strip[4]
    side.zip(subtract.call(strip[2], strip[5])) { |one, other| assert_in_delta one, other, 1.0e-9 }
    assert_equal([[0.0, 0.0], [1.0, 0.0], [1.0, 1.0], [0.0, 0.0], [1.0, 1.0], [0.0, 1.0]],
                 bolt_vertices(eye).first(6).map { |vertex| vertex[3, 2] })
  end
end
