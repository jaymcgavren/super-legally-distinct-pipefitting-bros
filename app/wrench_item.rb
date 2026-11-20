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
