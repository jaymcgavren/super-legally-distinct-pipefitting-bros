# One playthrough, from START to game over or the ending: score, lives, nuts,
# the shift clock, the last checkpoint and whether the wrench carries over.
class Run
  NUT_POINTS = 50
  NUTS_PER_LIFE = 50
  TIME_POINTS = 50      # per unit of shift time left at the end of a level
  LOW_TIME = 100        # the warning (and faster music) at this much time left

  attr_accessor :score, :lives, :nuts, :time, :rush, :checkpoint, :powered

  def initialize(rush = false)
    @rush = rush
    @score = 0
    @nuts = 0
    @lives = rush ? 5 : 3
    @checkpoint = nil
    @powered = rush
    @time = nil   # set by start_shift when a level loads
  end

  alias rush? rush

  # a nut: points, and true when it's the one that earns a life (the count
  # goes back down by NUTS_PER_LIFE; the caller awards the life)
  def add_nut
    @nuts += 1
    @score += NUT_POINTS
    return false if @nuts < NUTS_PER_LIFE
    @nuts -= NUTS_PER_LIFE
    true
  end

  def add_score(n)
    @score += n
  end

  # the shift clock, restarted at `length` units for each level (or life)
  def start_shift(length)
    @time = length
    @clock_frames = 0
    @warned = false
  end

  # one update step; true when the clock ticked down a unit
  def tick_clock
    @clock_frames += 1
    return false if @clock_frames < TICK_LENGTH
    @clock_frames = 0
    @time -= 1
    true
  end

  # true once per shift, when the time left reaches LOW_TIME
  def low_time_warning?
    return false unless @time == LOW_TIME && !@warned
    @warned = true
  end

  # turn up to `n` units of time left into points; returns the units moved
  def bank_time(n = @time)
    n = [@time, n].min
    @time -= n
    @score += n * TIME_POINTS
    n
  end
end

# The best score, kept in save slot 0.
class HighScore
  SLOT = 0

  attr_reader :value

  def initialize(gtk)
    @gtk = gtk
    @value = gtk.load_u32(SLOT) || 0
  end

  def submit(score)
    return unless score > @value
    @value = score
    @gtk.save_u32(SLOT, @value)
  end
end
