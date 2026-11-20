# The coffee break: start pauses and resumes. Goes back to the same Play.
class Paused < Scene
  def initialize(game, play)
    super(game)
    @play = play
  end

  def name = :paused
  def freezes_world? = true

  def update
    return unless controls.start_pressed?
    game.switch_to(@play)
    sound.play(:pause)
    sound.resume_music
  end

  def draw
    game.draw_world(true)
    screen.rect(0, 0, VIEW_WIDTH, PLAY_HEIGHT, BLACK, 140)
    screen.label(640, 380, 'COFFEE BREAK', 7, PALE_YELLOW)
    screen.label(640, 300, 'PRESS START', 3, WHITE)
  end
end
