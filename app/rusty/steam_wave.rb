class Rusty
  # GROUND POUND: a steam wave running along the floor until it leaves the arena
  class SteamWave < Shot
    def initialize(x, y, vx, left, right)
      super(x, y, 40, 36, vx, 0.0, 0)
      @left = left
      @right = right
    end

    def update(_game)
      @timer += 1
      @x += @vx
      @gone = true if @x < @left || @x > @right
    end

    def draw(screen, camera_x)
      x = @x.to_i - camera_x
      3.times do |i|
        h = 36 - i * 10 + ((@timer / 3 + i) % 2) * 6
        screen.rect(x + i * 12 - (@vx > 0 ? 0 : 12), Rusty::FLOOR, 16, h, STEAM, 220 - i * 50)
      end
    end
  end
end
