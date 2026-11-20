# The card before each level: its name, and lives left.
class Intro < Scene
  LENGTH = 150

  def name = :intro

  def update
    return unless @frames > LENGTH
    game.switch_to(Play.new(game))
    sound.music(:theme)
  end

  def draw
    level = game.level
    screen.outputs.background_color = BLACK
    game.draw_hud
    screen.label(640, 440, level.name, 6, PALE_YELLOW)
    screen.label(640, 370, level.title, 4, ORANGE)
    screen.label(640, 560, "BOSS RUSH #{game.level_index + 1} OF #{LEVELS.size}", 4, ALERT_RED) if run.rush?
    screen.sprite(BROS[game.bro][:path], 560, 210, 64, 80, FRAMES[:bro_stand])
    screen.label(680, 270, "x #{run.lives}", 5, WHITE)
  end
end
