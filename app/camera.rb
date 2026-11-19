# The view onto the level: `x` is the world x at the left edge of the screen
# (the camera never moves vertically). Holds the screen shake too.
class Camera
  attr_accessor :x

  def initialize(level)
    @level = level
    @x = 0.0
    @shake = 0
  end

  def max_x = @level.max_camera_x

  # put the left edge at `x` (or as near as the level's ends allow)
  def jump_to(x)
    @x = [[x, 0].max, max_x].min.to_f
  end

  # ease toward the player, looking ahead the way they face; in a boss
  # fight, toward the arena at the end of the level instead
  def follow(player, arena)
    target = player.x + player.w / 2 - 560 + player.facing * 90
    target = max_x if arena
    @x += (target - @x) * 0.1
    @x = 0.0 if @x < 0
    @x = max_x.to_f if @x > max_x
  end

  # shake for `frames` update steps
  def shake(frames)
    @shake = frames
  end

  # one step of the shake running down
  def settle
    @shake -= 1 if @shake > 0
  end

  # while shaking the world jumps 6 px left and right, every 2 frames of
  # the world clock
  def shake_x(frame)
    @shake > 0 ? ((frame % 4) < 2 ? 6 : -6) : 0
  end

  # draw with the view moved `dx` px (shake)
  def offset_by(dx)
    @x += dx
    yield
  ensure
    @x -= dx
  end
end
