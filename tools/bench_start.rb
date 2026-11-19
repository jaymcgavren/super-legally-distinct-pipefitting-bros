
# ── appended by tools/bench.sh (temp copy only) ──────────────────────
# Skip the title: start a game in the level given to bench.sh, with plenty
# of lives so the run stays in play. With BENCH_ARENA true, every
# (re)start puts the player inside Big Rusty's arena, so the klaxon, gate and
# fight keep happening; otherwise the player idles at the level start.
class Game
  alias bench_initialize initialize
  def initialize(args)
    bench_initialize(args)
    new_game(false)
    @lives = 99
    @level = BENCH_LEVEL
    to_intro
  end

  alias bench_to_intro to_intro
  def to_intro
    bench_to_intro
    return unless BENCH_ARENA && @boss
    @p.x = (@arena_c + 3) * T + 12
    @p.y = tile_bottom(7)
  end
end
