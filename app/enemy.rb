# Walking enemies. They wait off screen until the camera nears them, then
# walk, turn at walls, ledges and each other, and fall. `update` moves one
# a step; Game handles what touching the player does.

class Enemy < Actor
  WAKE_AHEAD = 48     # px past the right edge of the view
  NEAR_BEHIND = 900   # only enemies this close to the view move
  NEAR_AHEAD = 600
  KNOCK_VY = 12.0
  KNOCK_VX = 2.0
  KNOCKED_GRAVITY = 0.8

  attr_accessor :minion   # summoned by Big Rusty

  # Placed by a level marker at column c, row r; `offset` centres the body
  # in its tile.
  def self.at(level, c, r) = new(c * TILE + self::OFFSET, level.tile_bottom(r))

  def initialize(kind, x, y, w, h)
    super
    @minion = false
  end

  def spiky? = false
  def stomp_points(points) = points

  # Knocked out (by a wrench, a bumped tile or Rusty): flips and falls off
  # the screen.
  def knock(direction)
    @state = :dead
    @vy = KNOCK_VY
    @vx = direction * KNOCK_VX
  end

  def stomp(direction)
    knock(direction)
  end

  # One step. Returns true when this enemy is walking near the view, so it
  # can touch the player.
  def update(world, level, camera_x, others)
    unless @active
      return false if @x > camera_x + VIEW_WIDTH + WAKE_AHEAD
      @active = true
      @vx = -self.class::SPEED
    end
    @timer += 1
    if dead?
      @vy -= KNOCKED_GRAVITY
      @x += @vx
      @y += @vy
      return false
    end
    step_other
    return false unless walking?
    return false if @x < camera_x - NEAR_BEHIND || @x > camera_x + VIEW_WIDTH + NEAR_AHEAD
    @vx = (@vx < 0 ? -1 : 1) * pace
    world.fall(self)
    @vx = -@vx if world.move_x(self)
    world.move_y(self, false, false)
    turn_at_ledge(level) if @on_ground
    @state = :dead if @y < -100
    others.each do |other|
      next if other.equal?(self) || !other.active || !other.walking?
      @vx = -@vx if world.overlap?(self, other) && ((other.x - @x) * @vx) > 0
    end
    true
  end

  private

  # walking speed this step
  def pace = 1.0

  # for states other than walking and dead
  def step_other; end

  def turn_at_ledge(level)
    front_x = @vx > 0 ? @x + @w + 2 : @x - 2
    below = level.cell(level.column_at(front_x), level.row_at(@y - 4))
    @vx = -@vx unless SOLID[below] || below == '-'
  end
end
