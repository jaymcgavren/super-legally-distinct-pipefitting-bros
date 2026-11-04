# Super Legally Distinct Pipefitting Brothers - gameplay mockup (static scene)
# Atari 2600-style virtual screen: 160 x 180 "pixels", each 8 x 4 real px,
# filling the 1280x720 (16:9) canvas. Coordinates below are virtual, top-left.

PAL = {
  black:   [0, 0, 0],
  hud:     [24, 26, 24],
  sky:     [84, 138, 236], cloud: [236, 236, 236],
  bush:    [56, 156, 40],  bush_dk: [24, 104, 24],
  brick:   [176, 76, 40],  mortar: [92, 36, 20], coping: [180, 176, 164],
  girder:  [128, 136, 152], girder_hi: [188, 196, 208], rivet: [72, 76, 92],
  steel:   [96, 100, 120],
  copper:  [200, 108, 44], copper_hi: [236, 152, 80], flange: [140, 68, 24],
  red:     [200, 40, 40],  crate_dk: [124, 20, 20],
  yellow:  [236, 212, 64], gold: [228, 184, 48],
  skin:    [228, 160, 112], vest: [244, 120, 24], stripe: [252, 240, 160],
  jeans:   [48, 80, 176],   boots: [96, 56, 24],
  rust:    [168, 84, 32],   valve: [216, 48, 48],
  white:   [236, 236, 236],
}

def bar args, c, l, w, h, col
  args.outputs.solids << [c * 8, 720 - (l + h) * 4, w * 8, h * 4, *PAL[col]]
end

# 2600-style player graphic: 8 bits wide, one color per row, rows 2 lines tall
def sprite args, c, l, rows, colors, line_h = 2
  rows.each_with_index do |row, r|
    row.size.times do |i|
      bar(args, c + i, l + r * line_h, 1, line_h, colors[r]) if row[i] == "X"
    end
  end
end

PLAYER = [
  '..XXXX..', '.XXXXXX.', '..XXX...', 'X.XXX...', 'XXXXXX..',
  '..XXXX..', '..XXXX..', '..XXXX..', '..X..X..', '.XX...XX',
]
PLAYER_C = %i[yellow yellow skin skin vest vest stripe jeans jeans boots]

BLOB   = ['..XXXX..', '.XXXXXX.', 'XX.XX.XX', 'XXXXXXXX', 'XXXXXXXX', 'X.X..X.X']
CRAB   = ['...XX...', '.XXXXXX.', 'X..XX..X', '.XXXXXX.', '..X..X..', '.X....X.']
NUT    = ['.XXXX.', 'XX..XX', 'XX..XX', '.XXXX.']

def crate args, c, l
  bar args, c, l, 8, 12, :red
  bar args, c + 2, l - 2, 4, 2, :yellow        # handle
  bar args, c, l + 4, 8, 1, :crate_dk          # lid seam
  bar args, c + 3, l + 5, 2, 2, :yellow        # latch
end

def girder args, c, l, w
  bar args, c, l, w, 2, :girder_hi
  bar args, c, l + 2, w, 4, :girder
  0.step(w - 1, 4) { |i| bar args, c + i + 1, l + 3, 1, 1, :rivet }
end

def tick args
  args.outputs.background_color = PAL[:black]

  # sky: flat 2600 blue with a couple of blocky clouds
  bar args, 0, 16, 160, 132, :sky
  [[18, 34], [96, 26]].each do |c, l|
    bar args, c + 4, l, 8, 4, :cloud
    bar args, c, l + 4, 20, 4, :cloud
    bar args, c - 2, l + 8, 26, 4, :cloud
  end

  # green bushes along the roofline, a darker band at their base
  [[2, 12], [30, 18], [64, 10], [98, 16], [132, 14]].each do |c, w|
    bar args, c + w / 4, 132, w / 2, 4, :bush
    bar args, c + 1, 136, w - 2, 4, :bush
    bar args, c, 140, w, 8, :bush
    bar args, c, 145, w, 3, :bush_dk
  end

  # brick rooftops with stone coping, a gap between buildings
  [[0, 100], [116, 44]].each do |c, w|
    bar args, c, 148, w, 3, :coping
    bar args, c, 151, w, 1, :mortar
    bar args, c, 152, w, 28, :brick
    7.times do |row|
      l = 152 + row * 4
      bar args, c, l + 3, w, 1, :mortar
      off = row.even? ? 0 : 4
      off.step(w - 1, 8) { |i| bar args, c + i, l, 1, 3, :mortar }
    end
  end

  # floating girders and toolbox crates
  girder args, 20, 116, 16
  crate args, 50, 96
  crate args, 60, 92            # just bumped: lifted a little
  crate args, 70, 96
  girder args, 84, 100, 20

  # copper pipe run on stands, with flanges and a shutoff valve
  bar args, 118, 126, 42, 8, :copper
  bar args, 118, 127, 42, 2, :copper_hi
  120.step(156, 12) { |c| bar args, c, 124, 3, 12, :flange }
  [124, 148].each { |c| bar args, c, 134, 2, 14, :flange }
  sprite args, 136, 112, CRAB, [:valve] * 6

  # brass nuts (the collectible) above the right girder, one popping from the crate
  [86, 93, 100].each { |c| sprite args, c, 88, NUT, [:gold] * 4 }
  sprite args, 61, 78, NUT, [:gold] * 4

  # the pipefitter mid-jump under the bumped crate, a rust blob patrolling
  sprite args, 60, 106, PLAYER, PLAYER_C
  sprite args, 76, 136, BLOB, [:rust] * 6
  sprite args, 28, 104, BLOB, [:rust] * 6

  # HUD bar
  bar args, 0, 0, 160, 16, :hud
  hud = [[24, 'DEZ  004300'], [400, 'NUTS x12'], [700, 'JOBSITE 1-A'], [1050, 'SHIFT 287']]
  hud.each do |x, t|
    args.outputs.labels << { x: x, y: 704, text: t, size_px: 4, r: 236, g: 212, b: 64 }
  end
end
