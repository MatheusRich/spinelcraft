require_relative "test_helper"

class HeldItemTest < Minitest::Test
  # Records what HeldItem#place puts in the mesh.
  class Recorder
    attr_reader :frame, :models

    def initialize
      @models = []
    end

    def set_frame(*numbers)
      @frame = numbers
    end

    def item_model(block)
      @models << [:item, block]
    end

    def sprite_model(layer)
      @models << [:sprite, layer]
    end

    def frame_skin_box(*arguments)
      @models << [:arm, arguments[6], arguments[12]]
    end
  end

  def place(held, swing_left: 0.0, draw_time: -1.0, eat_time: -1.0, fov: 35.0 * Math::PI / 180.0, yaw: 0.0, pitch: 0.0)
    recorder = Recorder.new
    player = Player.new(0.0, 0.0, 0.0)
    player.yaw = yaw
    player.pitch = pitch
    held.place(recorder, player, 0.0, 0.0, 0.0, fov, swing_left, draw_time, eat_time)
    recorder
  end

  def settled(block)
    held = HeldItem.new
    held.change(block)
    held.ease(1.0, 0.0, 0.0)
    held
  end

  def test_change_is_true_only_for_a_new_block
    held = HeldItem.new

    assert_equal false, held.change(Block::AIR)

    assert_equal true, held.change(Block::BOW)
    assert_equal false, held.change(Block::BOW)
    assert_equal Block::BOW, held.block
    assert held.change(Block::AIR)
  end

  # The held item moves only a little in each frame while the player walks,
  # and when the player stops.
  def test_sway_is_smooth_while_the_player_walks_and_stops
    held = HeldItem.new
    dt = 1.0 / 60.0
    bob = 0.0
    last_x = held.sway_x
    last_y = held.sway_y
    most = 0.0
    150.times do |frame|
      walk = frame < 120 ? 1.0 : 0.0
      bob += 4.3 * dt * 2.6 if walk > 0.0
      held.ease(dt, walk, bob)
      most = [most, (held.sway_x - last_x).abs + (held.sway_y - last_y).abs].max
      last_x = held.sway_x
      last_y = held.sway_y
    end

    assert_operator most, :<, 0.006
    assert_operator most, :>, 0.0
  end

  def test_sway_fades_out_when_the_player_stops
    held = HeldItem.new
    60.times { held.ease(1.0 / 60.0, 1.0, 1.0) }
    walking = held.sway_x.abs + held.sway_y.abs
    120.times { held.ease(1.0 / 60.0, 0.0, 1.0) }

    assert_operator walking, :>, 0.0
    assert_operator held.sway_x.abs + held.sway_y.abs, :<, walking * 0.01
  end

  def test_the_empty_hand_shows_the_arm
    assert_equal [[:arm, Tex::SKINS + Tex::SKIN_PLAYER, false]], place(settled(Block::AIR)).models
  end

  def test_a_held_block_shows_its_model
    assert_equal [[:item, Block::STONE]], place(settled(Block::STONE)).models
  end

  def test_the_bow_shows_a_pulled_string_and_an_arrow_as_the_draw_grows
    held = settled(Block::BOW)

    assert_equal [[:item, Block::BOW]], place(held).models
    assert_equal [[:sprite, Tex::BOW_PULLING]], place(held, draw_time: 0.0).models
    assert_equal [[:sprite, Tex::BOW_PULLING]], place(held, draw_time: 0.64).models
    assert_equal [[:sprite, Tex::BOW_PULLING + 1]], place(held, draw_time: 0.65).models
    assert_equal [[:sprite, Tex::BOW_PULLING + 1]], place(held, draw_time: 0.89).models
    assert_equal [[:sprite, Tex::BOW_PULLING + 2]], place(held, draw_time: 0.9).models
    assert_equal [[:sprite, Tex::BOW_PULLING + 2]], place(held, draw_time: 3.0).models
  end

  def test_only_the_bow_changes_its_image_while_the_player_draws
    assert_equal [[:item, Block::STONE]], place(settled(Block::STONE), draw_time: 1.0).models
  end

  def test_a_new_item_starts_below_the_view_and_rises
    held = HeldItem.new
    held.change(Block::STONE)
    low = place(held).frame[1]
    held.ease(0.1, 0.0, 0.0)
    rising = place(held).frame[1]
    held.ease(1.0, 0.0, 0.0)

    assert_operator low, :<, rising
    assert_operator rising, :<, place(held).frame[1]
  end

  def test_drawing_pulls_the_item_toward_the_eye
    held = settled(Block::BOW)
    rest = place(held).frame
    drawn = place(held, draw_time: 1.0).frame
    # With the player facing -z, the item moves left of the view and back.
    assert_operator drawn[0], :<, rest[0]
    assert_operator drawn[2], :>, rest[2]
    assert_equal drawn, place(held, draw_time: 5.0).frame
  end

  def test_eating_lifts_the_food_toward_the_mouth
    held = settled(Block::PORKCHOP)
    rest = place(held).frame
    eating = place(held, eat_time: 1.0).frame

    assert_operator eating[0], :<, rest[0]
    assert_operator eating[1], :>, rest[1]
  end

  def test_a_swing_moves_the_item
    held = settled(Block::WOOD_SWORD)
    rest = place(held).frame
    swinging = place(held, swing_left: 0.5).frame

    refute_equal rest, swinging
    assert_equal rest, place(held, swing_left: 0.0).frame
  end

  def test_a_wider_view_scales_the_model_across_the_view
    held = settled(Block::STONE)
    narrow = place(held, fov: 35.0 * Math::PI / 180.0).frame
    wide = place(held, fov: 40.0 * Math::PI / 180.0).frame

    assert_in_delta narrow[3] * Math.tan(40.0 * Math::PI / 180.0) / Math.tan(35.0 * Math::PI / 180.0), wide[3], 1e-9
  end

  # The player faces -z, so the view has right +x, up +y and ahead -z. The
  # place of a held block is (0.56 right, 0.52 down, 0.72 ahead), as in
  # Minecraft (ItemInHandRenderer).
  def test_a_held_block_is_at_the_lower_right_in_front_of_the_eye
    assert_in_delta 0.56, place(settled(Block::STONE)).frame[0], 1e-9
    assert_in_delta(-0.52, place(settled(Block::STONE)).frame[1], 1e-9)
    assert_in_delta(-0.72, place(settled(Block::STONE)).frame[2], 1e-9)
  end

  def test_a_held_sprite_is_a_little_higher_right_and_back_of_a_block
    block = place(settled(Block::STONE)).frame
    sprite = place(settled(Block::WOOD_SWORD)).frame

    assert_in_delta block[0] + 1.13 / 16.0, sprite[0], 1e-9
    assert_in_delta block[1] + 3.2 / 16.0 + 0.08, sprite[1], 1e-9
    assert_in_delta block[2] + 1.13 / 16.0, sprite[2], 1e-9
  end

  def test_the_arm_is_at_the_lower_right_and_nearer_than_an_item
    frame = place(settled(Block::AIR)).frame

    assert_in_delta 0.6, frame[0], 1e-9
    assert_in_delta(-0.62, frame[1], 1e-9)
    assert_in_delta(-0.55, frame[2], 1e-9)
  end

  # Each model keeps its size, and its axes stay at right angles, whatever
  # the turn, the swing or the view.
  def test_the_axes_of_the_model_keep_their_size_and_right_angles
    sizes = { Block::STONE => 0.4, Block::WOOD_SWORD => 0.68, Block::AIR => 0.16 }
    sizes.each do |block, size|
      [0.0, 0.1, 0.5, 0.9].each do |swing_left|
        axes = place(settled(block), swing_left: swing_left).frame[3, 9].each_slice(3).to_a
        axes.each { |axis| assert_in_delta size, Math.sqrt(axis.sum { |part| part * part }), 1e-9 }
        [[0, 1], [0, 2], [1, 2]].each do |first, second|
          assert_in_delta 0.0, axes[first].zip(axes[second]).sum { |one, other| one * other }, 1e-9
        end
      end
    end
  end

  def test_a_block_turns_a_quarter_of_a_half_turn_around_up
    # The block turns 45 degrees: its first axis is between right and ahead.
    axis = place(settled(Block::STONE)).frame[3, 3]

    assert_in_delta(0.4 * Math.cos(Math::PI / 4.0), axis[0], 1e-9)
    assert_in_delta 0.0, axis[1], 1e-9
    assert_in_delta(0.4 * Math.sin(Math::PI / 4.0), axis[2].abs, 1e-9)
  end

  def test_a_swing_moves_the_item_left_and_up_and_ahead_at_first
    rest = place(settled(Block::WOOD_SWORD)).frame
    swinging = place(settled(Block::WOOD_SWORD), swing_left: 0.9).frame

    assert_operator swinging[0], :<, rest[0]
    assert_operator swinging[1], :>, rest[1]
    assert_operator swinging[2], :<, rest[2]
  end

  def test_a_swing_moves_the_empty_hand_left_and_up_and_ahead_at_first
    arm = settled(Block::AIR)
    rest = place(arm).frame
    swinging = place(arm, swing_left: 0.9).frame

    assert_operator swinging[0], :<, rest[0]
    assert_operator swinging[1], :>, rest[1]
    assert_operator swinging[2], :<, rest[2]
  end

  def test_the_sway_moves_the_item
    still = settled(Block::STONE)
    walking = settled(Block::STONE)
    60.times { walking.ease(1.0 / 60.0, 1.0, 1.0) }

    refute_equal place(still).frame, place(walking).frame
  end

  def test_a_new_item_does_not_stay_below_the_view_after_a_second
    held = HeldItem.new
    held.change(Block::STONE)
    held.ease(5.0, 0.0, 0.0)

    assert_in_delta(-0.52, place(held).frame[1], 1e-9)
  end

  # The frame of each state: the place of the model, then its three axes. The
  # numbers are what the code gave when it moved out of Game, and the game
  # drew the same models before the move.
  def test_the_model_frame_in_each_state
    {
      [Block::STONE, {}] =>
        [0.56, -0.52, -0.72, 0.282842712475, 0.0, -0.282842712475, 0.0, 0.4, 0.0, 0.282842712475, 0.0, 0.282842712475],
      [Block::WOOD_SWORD, { swing_left: 0.4 }] =>
        [0.278139121236, -0.473058097452, -1.077830872515, 0.231579819066, -0.571248675427, 0.287133659163,
         0.121345176745, -0.260567326482, -0.616262944246, -0.62773094195, -0.261112273157, -0.013200201712],
      [Block::AIR, { swing_left: 0.7 }] =>
        [0.30336530775, -0.738150635852, -0.87360679775, 0.032349212976, 0.007927918929, -0.156494972831,
         0.127317439863, -0.094481010533, 0.021531561844, -0.091344391873, -0.128881677325, -0.025410929208],
      [Block::PORKCHOP, { eat_time: Game::CHEW_START }] =>
        [0.27108381047, -0.091868665576, -0.549502447353, 0.48277172801, -0.092676633086, 0.469832417266,
         0.066416280078, 0.673654987126, 0.064636182288, -0.474257668757, 0.0, 0.487318852114],
      [Block::PORKCHOP, { eat_time: 1.1 }] =>
        [0.270625, -0.12, -0.549375, 0.483275891778, -0.092419059684, 0.469364602237,
         0.066297375379, 0.673690372061, 0.064388978953, -0.473760562356, 0.0, 0.487802141812],
      [Block::BOW, { draw_time: 0.5 }] =>
        [0.555625, -0.24, -0.589375, 0.0, -0.616289295185, -0.287380417984, 0.0, 0.287380417984, -0.616289295185, -0.68, 0.0, 0.0],
      [Block::STONE, { fov: 0.7 }] =>
        [0.67363098413, -0.625514485263, -0.72, 0.340235026354, 0.0, -0.282842712475, 0.0, 0.481164988664, 0.0, 0.340235026354, 0.0, 0.282842712475]
    }.each do |(block, arguments), expected|
      actual = place(settled(block), **arguments).frame

      expected.each_with_index do |number, index|
        assert_in_delta number, actual[index], 1e-9, "#{block} #{arguments} number #{index}"
      end
    end
  end

  def test_the_model_frame_while_the_item_rises_and_the_player_walks
    rising = HeldItem.new
    rising.change(Block::STONE)
    rising.ease(0.1, 0.0, 0.0)
    walking = settled(Block::STONE)
    60.times { walking.ease(1.0 / 60.0, 1.0, 1.0) }

    assert_in_delta(-0.745, place(rising).frame[1], 1e-9)
    assert_in_delta 0.571964100149, place(walking).frame[0], 1e-9
    assert_in_delta(-0.524588716126, place(walking).frame[1], 1e-9)
  end

  def test_a_block_has_no_move_left_over_from_a_sprite
    held = settled(Block::WOOD_SWORD)
    place(held)
    held.change(Block::STONE)
    held.ease(1.0, 0.0, 0.0)

    assert_equal place(settled(Block::STONE)).frame, place(held).frame
  end

  def test_a_swing_that_ended_does_not_move_the_item
    held = settled(Block::WOOD_SWORD)

    assert_equal place(held).frame, place(held, swing_left: -0.5).frame
  end

  # Whatever the held item was before, the model has the place of its own
  # kind: no turn or move stays from the arm, a sprite, food or a draw.
  def test_a_new_item_has_the_place_of_its_own_kind
    blocks = [Block::AIR, Block::WOOD_SWORD, Block::STONE, Block::PORKCHOP, Block::BOW]
    blocks.each do |before|
      blocks.each do |after|
        held = settled(before)
        place(held, eat_time: 1.0, draw_time: 1.0)
        held.change(after)
        held.ease(1.0, 0.0, 0.0)

        assert_equal place(settled(after)).frame, place(held).frame, "#{before} then #{after}"
      end
    end
  end

  # The player turns 90 degrees to the right, so ahead is +x and right is
  # +z: the block is 0.72 ahead, 0.56 right and 0.52 down.
  def test_the_model_follows_the_direction_of_the_player
    origin = place(settled(Block::STONE), yaw: Math::PI / 2.0).frame

    assert_in_delta 0.72, origin[0], 1e-9
    assert_in_delta(-0.52, origin[1], 1e-9)
    assert_in_delta 0.56, origin[2], 1e-9
  end

  def test_the_model_frame_when_the_player_looks_around
    {
      [Block::STONE, { yaw: 0.7, pitch: 0.4 }] =>
        [0.985986044502, -0.198570510419, -0.301332494829, 0.384158660837, 0.110144140226, -0.017040882549,
         -0.10034807354, 0.368424397601, 0.11913743068, 0.048501416896, -0.110144140226, 0.381465438714],
      [Block::STONE, { yaw: 0.7, pitch: 0.4, fov: 0.7 }] =>
        [1.099366253264, -0.295755787098, -0.259556216719, 0.428054723718, 0.110144140226, 0.019932261164,
         -0.120709949168, 0.443182302738, 0.143311901207, 0.092397479777, -0.110144140226, 0.418438582426],
      [Block::WOOD_SWORD, { yaw: -1.1, pitch: -0.3, swing_left: 0.6 }] =>
        [-0.790762713781, -0.813911060218, -0.515764970659, 0.608878103011, -0.284182006469, -0.104441576363,
         -0.30234305123, -0.58310451897, -0.176005111658, 0.016004219656, -0.204033593205, 0.648470629865],
      [Block::AIR, { yaw: 2.0, pitch: 0.5 }] =>
        [0.459485912353, -0.28041714214, 0.870137301087, -0.054782696755, 0.029626813037, 0.147380826723,
         -0.064895792734, -0.146153657184, 0.005257811069, 0.135600118811, -0.057977240716, 0.062058418746]
    }.each do |(block, arguments), expected|
      actual = place(settled(block), **arguments).frame

      expected.each_with_index do |number, index|
        assert_in_delta number, actual[index], 1e-9, "#{block} #{arguments} number #{index}"
      end
    end
  end

  # Before the first bite, the food only lifts.
  def test_the_model_frame_before_the_first_bite
    expected = [0.280409078587, -0.123261359529, -0.552092799608, 0.472412636685, -0.097908793215, 0.479207855645,
                0.068735855778, 0.672914458316, 0.069724557506, -0.484253738066, 0.0, 0.477386967951]
    actual = place(settled(Block::PORKCHOP), eat_time: 0.2).frame

    expected.each_with_index { |number, index| assert_in_delta number, actual[index], 1e-9 }
  end
end
