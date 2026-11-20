class Rusty
  # BOLT STORM: a shadow marks the spot for BOLT_WARNING steps (counting up
  # from t, which starts negative to stagger them), then the bolt drops
  class Bolt < Shot
    GRAVITY = 0.506   # 0.9, then 25% slower twice

    def initialize(x, timer)
      super(x, 700.0, 32, 40, 0.0, 0.0, timer)
    end

    def falling? = @timer >= BOLT_WARNING
    def harmful? = !@gone && falling?

    def update(game)
      @timer += 1
      return unless falling?
      @vy -= GRAVITY
      @y += @vy
      return if @y > Rusty::FLOOR
      @gone = true
      game.puff(@x + 16, Rusty::FLOOR)
      game.sound.play(:bump)
    end

    def draw(screen, camera_x)
      x = @x.to_i - camera_x
      return screen.sprite('sprites/shots.png', x - 8, @y.to_i, 48, 48, FRAMES[:bolt]) if falling?
      # a growing black shadow ringed by a flashing red/yellow marker, under a warning beam
      k = @timer < 0 ? 0 : @timer
      flash = (k / 4).even?
      w = 32 + (k * 48 / BOLT_WARNING)
      cx = x + 16
      screen.rect(cx - 16, Rusty::FLOOR, 32, 592, WARNING_RED, flash ? 80 : 45) if k > 0
      screen.rect(cx - w / 2 - 8, 124, w + 16, 26, flash ? WARNING_YELLOW : WARNING_RED, 255)
      screen.rect(cx - w / 2, 130, w, 14, BLACK, 235)
      screen.label(cx, 236, '!', 6, flash ? WARNING_YELLOW : WARNING_RED, true) if k > 0
    end
  end
end
