# Fixed things in a level, placed by markers: steam vents, checkpoint cones
# and the main valve. `c`/`r` are the marker's column and row; `x` is the
# world x of its left edge.

# A steam vent ('S', a solid block): every 3 seconds it sputters, then blows
# a jet of steam up to 3 tiles high, or less if something solid is above.
class Vent
  CYCLE = 180     # update steps per cycle; the phase is staggered by column
  SPUTTER = 100   # cycle step the warning puffs start
  JET = 130       # cycle step the jet starts; it blows to the end of the cycle
  MAX_TILES = 3

  attr_reader :c, :r, :x, :top, :height

  def initialize(level, c, r)
    @c = c
    @r = r
    @x = c * TILE
    @top = level.tile_top(r)
    @phase = (c * 37) % CYCLE
    tiles = 0
    tiles += 1 while tiles < MAX_TILES && !SOLID[level.cell(c, r - tiles - 1)]
    @height = tiles * TILE   # jet height in px; 0 if blocked right above
  end

  def cycle_step(frame) = (frame + @phase) % CYCLE
  def jetting?(frame) = @height > 0 && cycle_step(frame) >= JET
  def jet_starts?(frame) = @height > 0 && cycle_step(frame) == JET

  def draw(screen, camera_x, frame)
    k = cycle_step(frame)
    return if k < SPUTTER || @height <= 0
    x = @x - camera_x
    return if x < -TILE || x > VIEW_WIDTH
    if k < JET
      screen.rect(x + 24, @top + (k % 10) * 2, 16, 8, STEAM, 180) if (k / 5).even?
    else
      (@height / 16).times do |i|
        wobble = ((i + frame / 3) % 3 - 1) * 8
        w = 24 + (i * 3) % 16
        screen.rect(x + 32 - w / 2 + wobble, @top + i * 16, w, 16, STEAM, 200 - i * 6)
      end
    end
  end
end

# A checkpoint cone ('K'): lights when the player passes it; a life lost
# after that restarts here.
class Cone
  attr_reader :c, :r, :x, :y

  def initialize(level, c, r)
    @c = c
    @r = r
    @x = c * TILE
    @y = level.tile_bottom(r)
    @lit = false
  end

  def lit? = @lit

  def light
    @lit = true
  end

  def draw(screen, camera_x, frame)
    blink_on = @lit && (frame / 10).even?
    screen.tile('sprites/items.png', @x - camera_x, @y, FRAMES[blink_on ? :cone_lit : :cone_off])
  end
end

# The main valve on its standpipe ('G', or put down when Big Rusty falls):
# reach it, or hit it with the wrench, to clear the level. Three tiles tall;
# `turn` drives the wheel's animation, and in the ending the valve blows off
# (`gone`).
class Goal
  attr_reader :c, :r, :x, :y
  attr_accessor :turn, :gone

  def initialize(level, c, r)
    @c = c
    @r = r
    @x = c * TILE
    @y = level.tile_bottom(r)
    @turn = 0
    @gone = false
  end

  alias gone? gone

  def draw(screen, camera_x, tiles)
    x = @x - camera_x
    screen.tile(tiles, x, @y, FRAMES[:standpipe])
    screen.tile(tiles, x, @y + TILE, FRAMES[:standpipe])
    return if @gone
    screen.tile('sprites/items.png', x, @y + 2 * TILE, frame(:valve, (@turn / 5) % 3))
    screen.label(x + 32, @y + 3 * TILE + 28, 'MAIN', 2, WHITE, true)
  end
end
