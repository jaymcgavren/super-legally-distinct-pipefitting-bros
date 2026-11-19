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

  def blink?(period = 30) = (@frames / period) % 2 == 0
end

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
    if controls.start_pressed? || controls.jump_pressed?
      sound.play(:checkpoint)
      game.new_game(@rush_armed)
    end
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

class Play < Scene
  def name = :play

  def update
    if controls.start_pressed?
      game.switch_to(Paused.new(game, self))
      sound.play(:pause)
      sound.pause_music
      game.vent_sounds
      return
    end
    game.update_world
  end

  def draw
    game.draw_play
  end
end

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

# A life lost: a beat, then the player hops and falls off the screen.
class Dying < Scene
  HOP_AT = 31
  HOP = 15.0
  FALL_GRAVITY = 0.8
  LENGTH = 190

  def name = :dying

  def update
    player = game.player
    if @frames >= HOP_AT
      player.vy = HOP if @frames == HOP_AT
      player.vy -= FALL_GRAVITY
      player.y += player.vy
    end
    game.update_effects
    game.vent_sounds
    return if @frames < LENGTH
    run.lives -= 1
    if run.lives <= 0
      game.finish(:gameover)
    else
      game.to_intro
    end
  end

  def draw
    game.draw_world(true)
  end
end

# Level clear: the valve turns, the time left is banked as points, then on
# to the next level.
class Clear < Scene
  TURN_FOR = 100
  TALLY_AT = 110
  TALLY_STEP = 2
  MIN_LENGTH = 300

  def name = :clear

  def update
    game.settle_player(1)
    game.goal.turn += 1 if @frames < TURN_FOR
    if @frames > TALLY_AT && run.time > 0
      run.bank_time(TALLY_STEP)
      sound.play(:tick) if @frames % 4 == 0
    end
    game.update_effects
    game.update_wrench
    game.follow_player
    game.vent_sounds
    return unless run.time <= 0 && @frames > MIN_LENGTH
    game.next_level
  end

  def draw
    game.draw_world(true)
    screen.label(640, 470, 'MAIN SHUTOFF CLOSED!', 5, PALE_YELLOW, true)
    screen.label(640, 420, 'TIME BONUS', 3, WHITE, true) if @frames > TALLY_AT
  end
end

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
