# Dez (or Ozzie): the player's own movement, one step at a time. Game#
# update_player runs these in order with the collision and pickups between.
class Player < Actor
  attr_accessor :powered, :invuln, :coyote, :buffer, :jumping, :combo, :anim, :skid, :throw_t

  SKID_DECEL = [0.5, 0.3].freeze           # turning around: [on the ground, in the air]
  ACCEL_WALK = 0.2
  ACCEL_RUN = 0.28
  ACCEL_AIR = 0.18
  OVERSPEED_DECEL = 0.12            # above the top speed, on the ground
  FRICTION = [0.25, 0.04].freeze           # no direction held: [ground, air]
  SKID_MIN_SPEED = 1.5
  JUMP_BUFFER = 7                   # steps a jump press is remembered
  COYOTE_TIME = 6                   # steps you can still jump after a ledge
  THROW_POSE = 12

  def initialize(x, y)
    super(:player, x, y, 40, PLAYER_HEIGHT)
    @facing = 1
    @powered = false
    @invuln = 0
    @coyote = 0
    @buffer = 0
    @jumping = false
    @combo = 0
    @anim = 0.0
    @skid = false
    @throw_t = 0
  end

  def invulnerable? = @invuln > 0

  # carried along by the lift underfoot
  def ride_lift
    if @riding
      @x += @riding.dx
      @y += @riding.dy
    end
    @prev_y = @y
  end

  # Walk/run/skid toward `dir` (-1, 0, 1). Returns true when skidding.
  def apply_input(dir, run)
    max_speed = run ? RUN_MAX : WALK_MAX
    ground = @on_ground
    @skid = false
    if dir == 0
      f = ground ? FRICTION[0] : FRICTION[1]
      @vx = @vx.abs <= f ? 0.0 : @vx - f * (@vx > 0 ? 1 : -1)
    else
      if @vx * dir < 0
        @vx += dir * (ground ? SKID_DECEL[0] : SKID_DECEL[1])
        @skid = ground && @vx.abs > SKID_MIN_SPEED
      elsif @vx.abs <= max_speed
        @vx += dir * (ground ? (run ? ACCEL_RUN : ACCEL_WALK) : ACCEL_AIR)
        @vx = max_speed * dir if @vx.abs > max_speed
      elsif ground
        @vx -= dir * OVERSPEED_DECEL
      end
      @facing = dir
    end
    @skid
  end

  # Jump buffering and coyote time. Returns true when a jump starts.
  def jump(pressed)
    @buffer = pressed ? JUMP_BUFFER : @buffer - 1
    @coyote = @on_ground ? COYOTE_TIME : @coyote - 1
    return false unless @buffer > 0 && @coyote > 0
    @vy = @vx.abs >= RUN_JUMP_SPEED ? JUMP_VELOCITY_RUN : JUMP_VELOCITY
    @buffer = 0
    @coyote = 0
    @jumping = true
    @riding = nil
    true
  end

  # Holding jump on the way up goes higher; letting go cuts it short.
  def apply_gravity(jump_held)
    gravity = if @vy > 0
                @jumping && jump_held ? Physics::GRAVITY_HOLD : Physics::GRAVITY_CUT
              else
                Physics::GRAVITY_FALL
              end
    @vy -= gravity
    @vy = Physics::FALL_MAX if @vy < Physics::FALL_MAX
  end

  def land
    @jumping = false
    @combo = 0
  end

  def throw_wrench
    @throw_t = THROW_POSE
  end

  # walk cycle and countdowns
  def animate
    @anim += @vx.abs * 0.05 if @vx.abs > 0.3 && @on_ground
    @invuln -= 1 if @invuln > 0
    @throw_t -= 1 if @throw_t > 0
  end
end
