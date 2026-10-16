require_relative "test_helper"

class CameraTest < Minitest::Test
  # A camera at eye height 64 that looks along -z, with the far plane past
  # each box of the tests.
  def look_from(x, z)
    camera = Camera.new
    camera.update_camera(x, 64.0, z, 0.0, 0.0, 16.0 / 9.0, 300.0, 0.6)
    camera
  end

  def test_a_box_ahead_is_in_view_and_a_box_behind_is_not
    camera = look_from(0.0, 0.0)
    assert camera.box_in_view?(-8.0, 0.0, -40.0, 8.0, WY.to_f, -24.0, 100.0)
    refute camera.box_in_view?(-8.0, 0.0, 24.0, 8.0, WY.to_f, 40.0, 100.0)
  end

  def test_a_box_ahead_is_in_view_only_nearer_than_the_reach
    camera = look_from(0.0, 0.0)
    refute camera.box_in_view?(-8.0, 0.0, -140.0, 8.0, WY.to_f, -124.0, 100.0)
    refute camera.box_in_view?(-8.0, 0.0, -26.0, 8.0, WY.to_f, -10.0, 10.0)
    assert camera.box_in_view?(-8.0, 0.0, -26.0, 8.0, WY.to_f, -10.0, 10.01)
  end

  def test_the_height_of_a_box_counts_for_the_view_and_not_for_the_reach
    camera = look_from(0.0, 0.0)
    refute camera.box_in_view?(-8.0, 500.0, -40.0, 8.0, 600.0, -24.0, 100.0)
    assert camera.box_in_view?(-8.0, 0.0, -40.0, 8.0, 65.0, -24.0, 100.0)
  end

  def test_the_distance_to_a_box_is_to_its_nearest_point_along_x_and_z
    camera = look_from(0.0, 0.0)
    assert_equal 100.0, camera.box_distance2(-8.0, 10.0, 8.0, 26.0)
    assert_equal 100.0, camera.box_distance2(10.0, -8.0, 26.0, 8.0)
    assert_equal 100.0, camera.box_distance2(-26.0, -8.0, -10.0, 8.0)
    assert_equal 9.0 + 16.0, camera.box_distance2(3.0, 4.0, 19.0, 20.0)
    assert_equal 9.0 + 16.0, camera.box_distance2(-19.0, -20.0, -3.0, -4.0)
    assert_equal 0.0, camera.box_distance2(-8.0, -8.0, 8.0, 8.0)
  end

  def test_the_distance_counts_from_the_eye_of_the_last_update
    camera = look_from(100.0, -50.0)
    assert_equal 0.0, camera.box_distance2(96.0, -54.0, 112.0, -38.0)
    assert_equal 16.0, camera.box_distance2(104.0, -54.0, 120.0, -38.0)
    assert_equal 144.0, camera.box_distance2(96.0, -38.0, 112.0, -22.0)
  end

  def test_a_box_shows_only_its_sides_that_can_face_the_eye
    camera = look_from(0.0, 0.0)
    assert_equal 1 | 2 | 16 | 32, camera.facing_sides(-8.0, -8.0, 8.0, 8.0)
    # The box is to +x and to +z of the eye, so only its -x and -z sides
    # face it.
    assert_equal 2 | 32, camera.facing_sides(8.0, 8.0, 24.0, 24.0)
    assert_equal 1 | 16, camera.facing_sides(-24.0, -24.0, -8.0, -8.0)
    assert_equal 1 | 2 | 32, camera.facing_sides(-8.0, 0.0, 8.0, 16.0)
    assert_equal 2 | 16, camera.facing_sides(8.0, -24.0, 24.0, -8.0)
  end

  def test_an_eye_on_the_edge_of_a_box_sees_no_side_that_faces_away_from_the_box
    camera = look_from(0.0, 0.0)
    assert_equal 2 | 32, camera.facing_sides(0.0, 0.0, 16.0, 16.0)
    assert_equal 1 | 16, camera.facing_sides(-16.0, -16.0, 0.0, 0.0)
  end
end
