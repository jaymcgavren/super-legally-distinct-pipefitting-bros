
# ── appended by tools/bench.sh (temp copy only) ──────────────────────
# Where the run starts, from BENCH_START (bench.sh fills in the two
# placeholders):
#   :title   the normal title screen (no change)
#   :level   start a game in level BENCH_LEVEL; the player idles at its start
#   :arena   same, but every (re)start puts the player inside Big Rusty's
#            arena, so the klaxon, gate and fight keep happening
#   :ending  skip straight to the ending sequence (Rusty gone, valve turned)
# Lives are set to 99 so a run stays in play.
BENCH_MODE = :BENCH_START
# tile size: TILE since the refactor, T in un-refactored
BENCH_TILE = defined?(TILE) ? TILE : T

class Game
  alias bench_initialize initialize
  def initialize(args)
    bench_initialize(args)
    return if BENCH_MODE == :title
    new_game(false)
    @lives = 99
    @level = BENCH_MODE == :ending ? LEVELS.size - 1 : BENCH_LEVEL
    to_intro
  end

  alias bench_to_intro to_intro
  def to_intro
    bench_to_intro
    return unless @boss
    case BENCH_MODE
    when :arena
      @p.x = (@arena_c + 3) * BENCH_TILE + 12
      @p.y = tile_bottom(7)
    when :ending
      @boss = nil
      @goal = { c: @arena_c + 10, r: 7, turn: 0 }
      @p.x = (@arena_c + 9) * BENCH_TILE + 12
      @p.y = tile_bottom(7)
      @cam = max_cam.to_f
      start_ending
    end
  end
end
