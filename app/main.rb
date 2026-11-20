# SUPER LEGALLY DISTINCT PIPEFITTING BROTHERS
# Looks like a 2600 cart, plays like a 16-bit platformer.
#
# Screen: 1280x720 (16:9). Playfield is 10 rows of 64px tiles (y 0..640),
# HUD on top. Art is 2600-resolution (8x4 real px per art pixel).
# Controls: d-pad move, A (space / x) jump, B (z) run + throw wrench,
# Start (enter) pause.

require 'app/levels.rb'
require 'app/screen.rb'
require 'app/sound.rb'
require 'app/controls.rb'
require 'app/level.rb'
require 'app/physics.rb'
require 'app/camera.rb'
require 'app/run.rb'

TILE        = 64
ROWS        = 10
VIEW_WIDTH  = 1280
PLAY_HEIGHT = 640

WALK_MAX          = 4.2
RUN_MAX           = 6.8
PLAYER_HEIGHT     = 72
# Two jump heights: the full one only at (almost) top running speed, a lower
# one at any other speed, standing and walking included
JUMP_VELOCITY     = 19.0                # ~4.2 tiles held
JUMP_VELOCITY_RUN = 21.4                # ~5.4 tiles held
RUN_JUMP_SPEED    = RUN_MAX * 0.9
SHIFT_LENGTH      = 300
TICK_LENGTH       = 24                  # frames per SHIFT unit

# Colors used in more than one place (palette tables keep their own)
WHITE          = [255, 255, 255].freeze   # PRESS START, scores, popups
BLACK          = [0, 0, 0].freeze         # dimming overlays, backgrounds
PALE_YELLOW    = [252, 240, 160].freeze   # headline labels
ORANGE         = [244, 120, 24].freeze    # subtitles
GOLD           = [236, 212, 64].freeze    # BROTHERS, HUD text
ALERT_RED      = [232, 72, 64].freeze     # GAME OVER, BOSS RUSH, low time
WARNING_RED    = [232, 40, 40].freeze     # Big Rusty's WARNING card, bolt markers
WARNING_YELLOW = [252, 220, 40].freeze    # bolt markers, flashing
STEAM          = [236, 236, 236].freeze   # steam and dust
LIGHT_GRAY     = [200, 200, 200].freeze   # TOP score, skid dust
DARK_GRAY      = [60, 60, 60].freeze      # HUD rule, unselected slots
NEAR_BLACK     = [16, 16, 16].freeze      # HUD panel
TWINKLE        = [255, 255, 220].freeze   # the valve's twinkle in the ending

# Sprite-sheet frames: [source_x, source_y, source_w, source_h]. Every sheet
# is a horizontal strip of equal frames (see tools/make-assets.mjs), so an
# animation is its first frame here plus an index: `frame(:nut, 2)`.
FRAMES = {
  # tiles_<theme>.png
  brick: [0, 0, 8, 16], brick_top: [8, 0, 8, 16], girder: [16, 0, 8, 16],
  crate: [24, 0, 8, 16], crate_used: [32, 0, 8, 16], pipe: [40, 0, 8, 16],
  pipe_flange: [48, 0, 8, 16], pipe_stand: [56, 0, 8, 16], vent: [64, 0, 8, 16],
  standpipe: [72, 0, 8, 16], lift: [80, 0, 8, 16], back_wall: [88, 0, 8, 16],
  wood_floor: [96, 0, 8, 16], subfloor: [104, 0, 8, 16],
  # items.png
  nut: [0, 0, 8, 16],             # 4 frames: a spinning nut
  wrench_item: [32, 0, 8, 16], lunchbox: [40, 0, 8, 16],
  cone_off: [48, 0, 8, 16], cone_lit: [56, 0, 8, 16],
  valve: [64, 0, 8, 16],          # 3 frames: the handwheel turning
  # enemies.png
  blob: [0, 0, 8, 12],            # 2 walk frames
  blob_flat: [16, 0, 8, 12],
  crab: [24, 0, 8, 12],           # 2 walk frames
  crab_spin: [40, 0, 8, 12],      # 2 frames
  # dez.png / ozzie.png
  bro_stand: [0, 0, 8, 20],
  bro_run: [8, 0, 8, 20],         # 3 frames
  bro_jump: [32, 0, 8, 20], bro_skid: [40, 0, 8, 20], bro_die: [48, 0, 8, 20],
  bro_throw: [56, 0, 8, 20],
  # wrench.png
  wrench_spin: [0, 0, 8, 16],     # 7 frames
  wrench_back: [56, 0, 8, 16],    # slung on the player's back
  # rusty.png
  rusty_walk: [0, 0, 8, 28],      # 2 frames
  rusty_crouch: [16, 0, 8, 28], rusty_air: [24, 0, 8, 28], rusty_hurt: [32, 0, 8, 28],
  rusty_mouth: [40, 0, 8, 28], rusty_angry: [48, 0, 8, 28], rusty_crown: [56, 0, 8, 28],
  # shots.png
  glob: [0, 0, 8, 16], bolt: [8, 0, 8, 16]
}.freeze
FRAMES.each_value(&:freeze)

# FRAMES[name], or frame `index` of the animation starting there
def frame(name, index = 0)
  base = FRAMES[name]
  return base if index == 0
  [base[0] + index * base[2], base[1], base[2], base[3]]
end

SOLID = { '#' => true, 'F' => true, '=' => true, 'C' => true, 'W' => true, 'M' => true, 'U' => true, 'S' => true }.freeze
COMBO = [100, 200, 400, 800, 1000, 2000, 4000, 8000].freeze

OUTDOOR_THEMES = {
  day: { sky: [[84, 138, 236]], cloud: [236, 236, 236], bush: [56, 156, 40], bush_dark: [24, 104, 24],
         tiles: 'sprites/tiles_day.png' },
  dusk: { sky: [[72, 0, 120], [120, 16, 136], [160, 40, 120], [200, 72, 88], [228, 112, 56], [240, 160, 72]],
          cloud: [248, 184, 168], bush: [48, 100, 80], bush_dark: [28, 64, 52], tiles: 'sprites/tiles_dusk.png',
          sun: true },
  night: { sky: [[8, 12, 48]], cloud: [52, 60, 108], bush: [28, 84, 48], bush_dark: [12, 52, 28],
           tiles: 'sprites/tiles_night.png', stars: true }
}.freeze
INDOOR_TILES = { tiles: 'sprites/tiles_indoor.png', indoor: true }.freeze
# inside a building, the windows showing a day, sunset or night sky
THEMES = OUTDOOR_THEMES.merge(
  indoor: OUTDOOR_THEMES[:day].merge(INDOOR_TILES),
  indoor_dusk: OUTDOOR_THEMES[:dusk].merge(INDOOR_TILES),
  indoor_night: OUTDOOR_THEMES[:night].merge(INDOOR_TILES)
).freeze
BROS = [
  { name: 'DEZ',   path: 'sprites/dez.png' },
  { name: 'OZZIE', path: 'sprites/ozzie.png' }
].freeze
BUMP_ARC = [0, 8, 13, 16, 14, 10, 6, 2].freeze

require 'app/actor.rb'

def pad6(n)
  digits = n.to_i.to_s
  digits.size >= 6 ? digits : ('0' * (6 - digits.size)) + digits
end

def pad3(n)
  digits = [n.to_i, 0].max.to_s
  digits.size >= 3 ? digits : ('0' * (3 - digits.size)) + digits
end

# entities: their class bodies use the constants above
require 'app/player.rb'
require 'app/lift.rb'
require 'app/items.rb'
require 'app/props.rb'
require 'app/enemies.rb'
require 'app/wrench.rb'
require 'app/effects.rb'
require 'app/scenes.rb'

require 'app/game.rb'

require 'app/boss.rb'
require 'app/ending.rb'

def tick(args)
  $game ||= Game.new(args)
  $game.tick
end
