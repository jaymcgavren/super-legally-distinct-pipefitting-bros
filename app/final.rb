# The last card: game over (`:gameover`) or every level done (`:win`).
# Start goes back to the title.
class Final < Scene
  WAIT = 120   # steps before start works

  def initialize(game, kind)
    super(game)
    @kind = kind
  end

  def name = @kind

  def update
    game.to_title if @frames > WAIT && (controls.start_pressed? || controls.jump_pressed?)
  end

  def draw
    screen.outputs.background_color = BLACK
    game.draw_hud
    if @kind == :gameover
      screen.label(640, 440, 'GAME OVER', 8, ALERT_RED)
      screen.label(640, 350, 'YOU ARE FIRED', 4, WHITE)
    else
      screen.label(640, 500, run.rush? ? 'BOSS RUSH CLEARED!' : 'ALL MAINS SHUT OFF!', 6, PALE_YELLOW)
      screen.label(640, 420, run.rush? ? 'BIG RUSTY IS SCRAP' : 'OVERTIME APPROVED', 4, ORANGE)
      screen.label(640, 340, "FINAL SCORE #{pad6(run.score)}", 4, WHITE)
    end
    screen.label(640, 260, "TOP #{pad6(game.high_score.value)}", 3, LIGHT_GRAY)
    screen.label(640, 160, 'PRESS START', 3, WHITE) if @frames > WAIT && blink?
  end
end
