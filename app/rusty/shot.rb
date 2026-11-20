class Rusty
  # Rusty's shots. Each moves itself one step in `update(game)`, and is
  # `harmful?` while it can hurt the player (Game#update_shots checks that).
  class Shot
    attr_reader :x, :y, :w, :h, :vx, :vy, :timer

    def initialize(x, y, w, h, vx, vy, timer)
      @x = x
      @y = y
      @w = w
      @h = h
      @vx = vx
      @vy = vy
      @timer = timer
      @gone = false
    end

    def gone? = @gone
    def harmful? = !@gone
  end
end
