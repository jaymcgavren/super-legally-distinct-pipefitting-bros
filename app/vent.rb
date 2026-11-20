# Fixed things in a level, placed by markers: steam vents (Vent), checkpoint
# cones (Cone) and the main valve (Goal). `c`/`r` are the marker's column and row; `x` is the
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
