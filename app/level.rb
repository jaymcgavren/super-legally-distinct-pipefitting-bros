# One level's tile grid, built from LEVELS[index]: either its own `rows` or
# its segments laid side by side. Row 0 is the top; column 0 the left edge.
# Off the left or right end is solid wall; above and below is open air.
class Level
  # tiles that mark where things start; each_marker clears them to air,
  # except vents, which stay in the grid as solid blocks
  MARKERS = 'PrvLHSKGB'

  attr_reader :index, :data, :theme, :columns

  def initialize(index)
    @index = index
    @data = LEVELS[index]
    @theme = THEMES[@data[:theme]]
    rows = @data[:rows]
    unless rows
      rows = Array.new(ROWS) { '' }
      @data[:segs].each { |segment| segment.each_with_index { |row, r| rows[r] += row } }
    end
    @columns = rows[0].size
    @grid = rows.map(&:chars)
  end

  def name = @data[:name]
  def title = @data[:title]

  def cell(c, r)
    return '#' if c < 0 || c >= @columns
    return '.' if r < 0 || r >= ROWS
    @grid[r][c]
  end

  def set_cell(c, r, tile)
    @grid[r][c] = tile
  end

  # row `r` as an array of tiles, for drawing
  def row(r) = @grid[r]

  # each marker tile, top row first, left to right; the tile is cleared after
  # the block runs, so the block still sees it in the grid
  def each_marker
    @grid.each_with_index do |row, r|
      row.each_with_index do |tile, c|
        next unless MARKERS.include?(tile)
        yield tile, c, r
        row[c] = '.' unless tile == 'S'
      end
    end
  end

  def column_at(x) = (x / TILE).floor
  def row_at(y) = ROWS - 1 - (y / TILE).floor
  def tile_bottom(r) = (ROWS - 1 - r) * TILE
  def tile_top(r) = (ROWS - r) * TILE
  def width = @columns * TILE
  def max_camera_x = width - VIEW_WIDTH
end
