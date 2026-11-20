# The crab: every so often it flashes a warning, then spins with its spikes
# out and rushes; it can't be stomped then. Worth double when stomped.
class Crab < Enemy
  SPEED = 1.2
  SPIN_SPEED = 2.6
  OFFSET = 6
  CYCLE = 220   # steps per cycle; staggered by column
  WARN = 120    # cycle step the warning starts
  SPIN = 150    # cycle step the spin starts; it lasts to the end of the cycle

  def self.at(level, c, r)
    crab = super
    crab.cycle = (c * 29) % 200
    crab
  end

  attr_writer :cycle

  def initialize(x, y)
    super(:crab, x, y, 52, 44)
    @cycle = 0
    @spiky = false
    @warning = false
  end

  def spiky? = @spiky
  def warning? = @warning
  def stomp_points(points) = points * 2

  def draw(screen, x)
    source = @spiky ? frame(:crab_spin, (@timer / 4) % 2) : frame(:crab, (@timer / 12) % 2)
    alpha = @warning && (@timer / 3).even? ? 110 : 255
    screen.sprite('sprites/enemies.png', x - OFFSET, @y.to_i, TILE, 48, source, alpha: alpha, flip_v: dead?)
  end

  private

  def pace
    k = (@timer + @cycle) % CYCLE
    @spiky = k >= SPIN
    @warning = k >= WARN && k < SPIN
    @spiky ? SPIN_SPEED : SPEED
  end
end
