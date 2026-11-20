class Rusty
  # RUST SPIT: a lobbed glob that bursts on the floor, a solid tile or the wrench
  class RustGlob < Shot
    GRAVITY = 0.5

    def initialize(x, y, vx)
      super(x, y, 32, 32, vx, 12.0, 0)
    end

    def update(game)
      @timer += 1
      @vy -= GRAVITY
      @x += @vx
      @y += @vy
      level = game.level
      burst(game, 0) if @y <= Rusty::FLOOR || SOLID[level.cell(level.column_at(@x + 16), level.row_at(@y))]
    end

    def burst(game, dy)
      @gone = true
      game.puff(@x + 16, @y + dy)
    end

    def draw(screen, camera_x)
      screen.sprite('sprites/shots.png', @x.to_i - camera_x, @y.to_i, 32, 32, FRAMES[:glob])
    end
  end
end
