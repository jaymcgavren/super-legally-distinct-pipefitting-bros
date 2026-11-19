
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
# Names that the refactor changed; the patch must also build un-refactored.
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

  def bench_iv(new, old) = instance_variable_defined?(new) ? new : old

  alias bench_to_intro to_intro
  def to_intro
    bench_to_intro
    return unless @boss
    player = instance_variable_get(bench_iv(:@player, :@p))
    arena = instance_variable_get(bench_iv(:@arena_column, :@arena_c))
    case BENCH_MODE
    when :arena
      player.x = (arena + 3) * BENCH_TILE + 12
      player.y = tile_bottom(7)
    when :ending
      @boss = nil
      @goal = { c: arena + 10, r: 7, turn: 0 }
      player.x = (arena + 9) * BENCH_TILE + 12
      player.y = tile_bottom(7)
      instance_variable_set(bench_iv(:@camera_x, :@cam), (respond_to?(:max_camera_x, true) ? max_camera_x : max_cam).to_f)
      start_ending
    end
  end
end
