# Title: the level scrolls by behind the logo; pick Dez or Ozzie, press
# start. Up Up Down Down Left Right Left Right locks in Boss Rush; the next
# game started is a Boss Rush run.
class Title < Scene
  RUSH_CODE = %i[up up down down left right left right].freeze
  # nut chime climbing a major scale, one step per correct code press
  CODE_STEPS = [0, 2, 4, 5, 7, 9, 11, 12].freeze
  SCROLL_SPEED = 1.5

  def initialize(game)
    super
    @rush_armed = false
    @code_index = 0
  end

  def name = :title
  def rush_armed? = @rush_armed

  def update
    camera = game.camera
    camera.x = (@frames * SCROLL_SPEED) % camera.max_x
    if controls.left_pressed? || controls.right_pressed?
      game.bro = 1 - game.bro
      sound.play(:tick)
    end
    if !@rush_armed && feed_code
      @rush_armed = true
      sound.play(:oneup)
    end
    return unless controls.start_pressed? || controls.jump_pressed?
    sound.play(:checkpoint)
    game.new_game(@rush_armed)
  end

  def draw
    game.draw_world(false)
    screen.rect(0, 0, VIEW_WIDTH, 720, BLACK, 120)
    screen.shadow_label(640, 640, 'SUPER LEGALLY DISTINCT', 5, PALE_YELLOW)
    screen.shadow_label(640, 580, 'PIPEFITTING', 12, ORANGE)
    screen.shadow_label(640, 470, 'BROTHERS', 12, GOLD)
    2.times do |i|
      x = 480 + i * 320
      selected = i == game.bro
      screen.rect(x - 56, 196, 112, 120, selected ? PALE_YELLOW : DARK_GRAY)
      screen.rect(x - 48, 204, 96, 104, [20, 20, 40])
      source = selected ? frame(:bro_run, (@frames / 8) % 3) : FRAMES[:bro_stand]
      screen.sprite(BROS[i][:path], x - 32, 216, 64, 80, source, flip: i == 1)
      screen.shadow_label(x, 180, BROS[i][:name], 4, selected ? PALE_YELLOW : [140, 140, 140])
    end
    screen.shadow_label(640, 120, 'PRESS START', 4, WHITE) if blink?
    screen.shadow_label(640, 366, 'BOSS RUSH', 4, ALERT_RED) if @rush_armed
    screen.shadow_label(640, 70, "TOP #{pad6(game.high_score.value)}", 3, LIGHT_GRAY)
    screen.shadow_label(640, 30, 'ANY RESEMBLANCE TO PLUMBERS LIVING OR DEAD IS PURELY COINCIDENTAL', 2, [180, 180, 180])
  end

  private

  # advance the code matcher; true once the whole code is in
  def feed_code
    press = controls.code_press
    return false unless press
    if press == RUSH_CODE[@code_index]
      @code_index += 1
    else
      @code_index = press == :up ? (@code_index == 2 ? 2 : 1) : 0
    end
    sound.chime(CODE_STEPS[@code_index - 1]) if @code_index > 0
    return false unless @code_index == RUSH_CODE.size
    @code_index = 0
    true
  end
end
