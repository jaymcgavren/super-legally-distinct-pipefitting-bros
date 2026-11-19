# Draws into the current outputs: the screen, or a render target while
# `draw_into` runs (the ending draws the level into one and lifts it away).
class Screen
  attr_accessor :outputs

  def initialize(outputs)
    @outputs = outputs
  end

  # `frame` is a sprite-sheet rect: FRAMES[name] or frame(name, index)
  def sprite(path, x, y, w, h, frame, flip: false, alpha: 255, angle: 0, flip_v: false)
    @outputs.sprites << { x: x, y: y, w: w, h: h, path: path, source_x: frame[0], source_y: frame[1],
                          source_w: frame[2], source_h: frame[3], flip_horizontally: flip, flip_vertically: flip_v,
                          a: alpha, angle: angle }
  end

  # a TILE-sized sprite, the common case; positional, because keyword
  # parameters make every call slower in mruby, even calls that pass none
  def tile(path, x, y, frame)
    @outputs.sprites << { x: x, y: y, w: TILE, h: TILE, path: path, source_x: frame[0], source_y: frame[1],
                          source_w: frame[2], source_h: frame[3], flip_horizontally: false, flip_vertically: false,
                          a: 255, angle: 0 }
  end

  def rect(x, y, w, h, color, alpha = 255)
    @outputs.sprites << { x: x, y: y, w: w, h: h, path: 'sprites/px.png',
                          r: color[0], g: color[1], b: color[2], a: alpha }
  end

  # centred text
  def label(x, y, text, size, color, shadow = false)
    @outputs.labels << { x: x + size, y: y - size, text: text, size_px: size, alignment_enum: 1, r: 0, g: 0, b: 0 } if shadow
    @outputs.labels << { x: x, y: y, text: text, size_px: size, alignment_enum: 1, r: color[0], g: color[1], b: color[2] }
  end

  def shadow_label(x, y, text, size, color)
    label(x, y, text, size, color, true)
  end

  # draw into `target` for the duration of the block
  def draw_into(target)
    saved = @outputs
    @outputs = target
    yield
  ensure
    @outputs = saved
  end
end
