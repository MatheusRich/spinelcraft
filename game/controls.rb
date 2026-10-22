# What the player asks to do in a frame: walk, strafe, jump, sneak and
# sprint. Game#read_move_keys fills it from the keys, and the autopilot
# drives it too. Player#update and the boat that the player rides read
# it. Minecraft keeps the same in the Input of the player, and Luanti in
# the PlayerControl of the player.
class Controls
  # Two presses of W within this many seconds start a sprint, until W is
  # released.
  DOUBLE_TAP = 0.3

  # forward and strafe go from -1 to 1: forward along the view, and strafe
  # to the right of it.
  attr_reader :forward, :strafe, :jump, :sneak, :sprint

  def initialize
    @forward = 0.0
    @strafe = 0.0
    @jump = false
    @sneak = false
    @sprint = false
    # True after two presses of W, until W is released.
    @tap_sprint = false
    @last_tap = -1.0
  end

  # The keys of a frame. The player sprints only forward. The wiki does not
  # confirm this.
  def hold(forward, strafe, jump:, sneak:, sprint:)
    @forward = forward
    @strafe = strafe
    @jump = jump
    @sneak = sneak
    @sprint = forward > 0.0 && sprint
    nil
  end

  # No key is down, as when the mouse is free.
  def release_keys = hold(0.0, 0.0, jump: false, sneak: false, sprint: false)

  # The autopilot flies forward in a sprint.
  def cruise
    @forward = 1.0
    @sprint = true
    nil
  end

  # A press of W at the time now, in seconds. The second press within
  # DOUBLE_TAP starts a sprint.
  def tap_forward(now)
    @tap_sprint = now - @last_tap < DOUBLE_TAP && now > @last_tap
    @last_tap = now
  end

  # W is up, so the sprint of two presses ends.
  def release_forward
    @tap_sprint = false
  end

  def tap_sprint? = @tap_sprint
end
