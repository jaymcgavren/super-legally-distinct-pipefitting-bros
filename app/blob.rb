# The blob: slow, and squashed flat when stomped.
class Blob < Enemy
  SPEED = 1.0
  OFFSET = 8
  FLAT_TIME = 30   # steps a squashed blob stays before it vanishes

  # Big Rusty spits one out, already awake and moving
  def self.minion(x, y, direction)
    blob = new(x, y)
    blob.active = true
    blob.vx = direction * SPEED
    blob.vy = 8.0
    blob.minion = true
    blob
  end

  def initialize(x, y)
    super(:blob, x, y, 48, 40)
  end

  def flat? = @state == :flat

  def stomp(_direction)
    @state = :flat
    @flat_t = 1   # counted from the step it was squashed
  end

  def draw(screen, x)
    source = flat? ? FRAMES[:blob_flat] : frame(:blob, (@timer / 10) % 2)
    screen.sprite('sprites/enemies.png', x - OFFSET, @y.to_i, TILE, 48, source, flip: @vx > 0, flip_v: dead?)
  end

  private

  def step_other
    return unless flat?
    @flat_t += 1
    @state = :gone if @flat_t > FLAT_TIME
  end
end
