# A moving girder, two tiles wide, swinging up and down ('L' in a level) or
# left and right ('H') around where it was placed. Physics#move_y lands
# things on it; a rider moves with it by `dx`/`dy`, its last step's motion.
class Lift
  WIDTH = 2 * TILE
  HEIGHT = 16
  SWING = 2 * TILE    # each way from the base position
  PERIOD = 240        # update steps per swing, there and back

  # A vertical lift over a pit with a ceiling above swings lower, and half as
  # far, so a full running jump off it never hits the ceiling: indoors the
  # standard +/-2 tile swing put the lift so close to the roof that jumps
  # across the pit got cut short.
  JUMP_RISE = JUMP_VELOCITY_RUN**2 / (2 * Physics::GRAVITY_HOLD)

  attr_reader :x, :y, :w, :h, :axis, :base_x, :base_y, :amplitude, :phase, :dx, :dy

  # the lift whose marker is at column c, row r; axis :y (L) or :x (H)
  def initialize(level, c, r, axis)
    @x = (c * TILE).to_f
    @y = (level.tile_top(r) - HEIGHT).to_f
    @w = WIDTH
    @h = HEIGHT
    @axis = axis
    @base_x = @x
    @base_y = @y
    @amplitude = SWING
    @phase = c * 0.7
    @dx = 0.0
    @dy = 0.0
    fit_under_ceiling(level, c, r) if axis == :y
  end

  # `frame` is the world clock
  def update(frame)
    swing = Math.sin(frame * 6.2832 / PERIOD + @phase)
    if @axis == :x
      new_x = @base_x + swing * @amplitude
      @dx = new_x - @x
      @dy = 0.0
      @x = new_x
    else
      new_y = @base_y + swing * @amplitude
      @dy = new_y - @y
      @dx = 0.0
      @y = new_y
    end
  end

  def draw(screen, camera_x, tiles)
    x = @x.to_i - camera_x
    screen.tile(tiles, x, @y.to_i - 48, FRAMES[:lift])
    screen.tile(tiles, x + TILE, @y.to_i - 48, FRAMES[:lift])
  end

  private

  def fit_under_ceiling(level, c, r)
    columns = [c, c + 1]
    return unless columns.all? { |column| (r + 1...ROWS).none? { |row| SOLID[level.cell(column, row)] } }
    ceil = (0...r).to_a.reverse.find { |row| columns.any? { |column| SOLID[level.cell(column, row)] } }
    return unless ceil
    max_top = level.tile_bottom(ceil) - PLAYER_HEIGHT - JUMP_RISE
    top = @y + @h
    return if top + 2 * TILE <= max_top
    @amplitude = TILE
    @base_y = max_top - TILE - @h
    @y = @base_y
  end
end
