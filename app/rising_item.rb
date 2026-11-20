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
