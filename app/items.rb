# Things that come out of crates. Each `update(world)` moves the item one
# step and returns true when the player can pick it up this step; Game
# decides what picking it up does. `world` is the Game, for its physics.

# A nut knocked out of a crate: it pops up, spins and vanishes. Already
# counted when it popped, so it can't be picked up.
class PopNut < Actor
  LIFETIME = 26

  def initialize(x, top)
    super(:popnut, x, top, 64, 64)
    @vy = 16.0
  end

  def update(_world)
    @timer += 1
    @vy -= 1.2
    @y += @vy
    @state = :gone if @timer > LIFETIME
    false
  end

  def draw(screen, camera_x, _frame)
    screen.tile('sprites/items.png', @x.to_i - camera_x, @y.to_i, frame(:nut, (@timer / 3) % 4))
  end
end

# An item that rises out of the top of its crate before it can be taken.
class RisingItem < Actor
  RISE = 64   # px, 2 per step

  def initialize(kind, x, top)
    super(kind, x + 4, top - RISE, 56, 56)
    @rise = RISE
  end

  def rising? = @rise > 0

  def update(world)
    @timer += 1
    if rising?
      @rise -= 2
      @y += 2
      return false
    end
    move(world)
    true
  end

  # after the rise
  def move(_world); end
end

# The wrench: powers the player up. Bobs in place once it's out.
class WrenchItem < RisingItem
  def initialize(x, top)
    super(:wrench_item, x, top)
  end

  def draw(screen, camera_x, frame)
    bob = rising? ? 0 : ((frame / 12) % 2) * 4
    screen.tile('sprites/items.png', @x.to_i - camera_x - 4, @y.to_i + bob, FRAMES[:wrench_item])
  end
end

# The lunchbox (from a hidden crate): an extra life. It slides away and
# bounces off walls, and can fall into a pit.
class Lunch < RisingItem
  def initialize(x, top)
    super(:lunch, x, top)
    @vx = 2.5
  end

  def move(world)
    @vy -= Physics::GRAVITY_FALL
    @vx = -@vx if world.move_x(self)
    world.move_y(self, false, false)
    @state = :gone if @y < -100
  end

  def draw(screen, camera_x, _frame)
    screen.tile('sprites/items.png', @x.to_i - camera_x - 4, @y.to_i, FRAMES[:lunchbox])
  end
end
