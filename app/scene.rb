# The game's modes, one object each. Game holds the current one (@scene)
# and swaps it with `switch_to`; every update step it ticks the scene's own
# timer (`frames`, steps since the scene began) and calls `update`, and
# every host frame it calls `draw`. The world itself (level, player,
# enemies, camera) lives in Game; scenes drive it and add what's on top.
class Scene
  attr_reader :game
  attr_accessor :frames

  def initialize(game)
    @game = game
    @frames = 0
  end

  # The world clock (Game's @frame: lifts, vents, blinking) stops while
  # this scene is up.
  def freezes_world? = false

  def update; end
  def draw; end

  private

  def screen = @game.screen
  def sound = @game.sound
  def controls = @game.controls
  def run = @game.run

  def blink?(period = 30) = (@frames / period).even?
end
