# The thrown pipe wrench: a boomerang. It flies out, slows, turns and homes
# back to the player's hand. Knocking into the main valve bounces it off in
# a short arc first. Game decides what it hits.
class Wrench < Actor
  THROW_SPEED = 16.0
  CARRY = 0.5          # share of the player's speed it keeps
  DRAG = 0.5           # per step, until it turns back
  HOME_ACCEL = 0.6
  HOME_MAX = 13.0
  CATCH_RANGE = 40
  LIFETIME = 150       # steps; then it's dropped wherever it is
  BOUNCE_STEPS = 14
  BOUNCE_GRAVITY = 0.7
  SPIN_FRAMES = 7      # hand-drawn spin frames

  def initialize(player)
    facing = player.facing
    super(:wrench, player.x + (facing > 0 ? player.w : -40), player.y + 36, 40, 20)
    @vx = facing * THROW_SPEED + player.vx * CARRY
    @facing = facing
    @back = false
    @bounce = 0
  end

  def back? = @back
  def caught? = gone?
  def expired? = @t > LIFETIME
  def heading = @vx > 0 ? 1 : -1

  def turn_back
    @back = true
  end

  # off the main valve: a short arc before it heads home
  def bounce_off
    @vx = @vx > 0 ? -7.0 : 7.0
    @vy = 7.0
    @back = true
    @bounce = BOUNCE_STEPS
    @t = 0
  end

  # One step. Returns true when it's in free flight and can hit things;
  # `caught?` once it's back in the player's hand.
  def update(player)
    @t += 1
    if @bounce > 0
      @bounce -= 1
      @vy -= BOUNCE_GRAVITY
      @x += @vx
      @y += @vy
      return false
    elsif !@back
      @vx -= @facing * DRAG
      @back = true if @vx * @facing <= 0
    else
      dx = (player.x + player.w / 2) - (@x + @w / 2)
      dy = (player.y + 40) - (@y + @h / 2)
      distance = Math.sqrt(dx * dx + dy * dy)
      distance = 1 if distance < 1
      speed = [@vx.abs + @vy.abs + HOME_ACCEL, HOME_MAX].min
      @vx = dx / distance * speed
      @vy = dy / distance * speed
      if distance < CATCH_RANGE
        @state = :gone
        return false
      end
    end
    @x += @vx
    @y += @vy
    true
  end

  # mirroring reverses the spin for left throws
  def draw(screen, camera_x)
    f = (@t / 2) % SPIN_FRAMES
    screen.sprite('sprites/wrench.png', @x.to_i - camera_x - 4, @y.to_i - 14, 48, 48, frame(:wrench_spin, f), flip: @facing < 0)
  end
end
