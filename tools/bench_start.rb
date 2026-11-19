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
# (mruby has no `defined?` keyword: it parses as a method call)
BENCH_TILE = Object.const_defined?(:TILE) ? TILE : T

class Game
  alias bench_initialize initialize
  def initialize(args)
    bench_initialize(args)
    return if BENCH_MODE == :title
    new_game(false)
    if instance_variable_defined?(:@run)
      @run.lives = 99
    else
      @lives = 99
    end
    instance_variable_set(bench_iv(:@level_index, :@level), BENCH_MODE == :ending ? LEVELS.size - 1 : BENCH_LEVEL)
    to_intro
  end

  def bench_iv(new, old) = instance_variable_defined?(new) ? new : old

  alias bench_to_intro to_intro
  def bench_max_camera_x
    return @level.max_camera_x if @level.respond_to?(:max_camera_x)
    respond_to?(:max_camera_x, true) ? max_camera_x : max_cam
  end

  def to_intro
    bench_to_intro
    return unless @boss
    player = instance_variable_get(bench_iv(:@player, :@p))
    arena = instance_variable_get(bench_iv(:@arena_column, :@arena_c))
    case BENCH_MODE
    when :arena
      player.x = (arena + 3) * BENCH_TILE + 12
      player.y = (ROWS - 1 - 7) * BENCH_TILE
    when :ending
      @boss = nil
      @goal = Object.const_defined?(:Goal) ? Goal.new(@level, arena + 10, 7) : { c: arena + 10, r: 7, turn: 0 }
      player.x = (arena + 9) * BENCH_TILE + 12
      player.y = (ROWS - 1 - 7) * BENCH_TILE
      if instance_variable_defined?(:@camera)
        @camera.x = @camera.max_x.to_f
      else
        instance_variable_set(bench_iv(:@camera_x, :@cam), bench_max_camera_x.to_f)
      end
      start_ending
    end
  end
end
