# Things that come out of crates (PopNut, WrenchItem, Lunch). Each `update(world)` moves the item one
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
