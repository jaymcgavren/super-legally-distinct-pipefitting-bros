# Headless gameplay harness: runs app/main.rb under host Ruby with a stub
# `args`, so scenarios can be scripted and asserted.  ruby tools/sim.rb
$LOAD_PATH.unshift File.expand_path('..', __dir__)

class Keys
  NAMES = %i[left right up down a b x y start select]
  attr_accessor(*NAMES)
  attr_accessor :left_analog_x_perc
  def initialize; NAMES.each { |n| send("#{n}=", false) }; end
end

class KB < Keys
  attr_accessor :key_down
  def initialize; super; @key_down = Keys.new; end
end

class Outs
  attr_accessor :background_color
  def initialize; @h = Hash.new { |h, k| h[k] = [] }; end
  def method_missing(n, *a) = n.to_s.end_with?('=') ? nil : @h[n]
  def respond_to_missing?(*) = true
  def [](k) = (@t ||= {})[k] ||= Outs.new
  def clear = (@h.clear; @t&.each_value(&:clear))
end

class Gtk
  attr_accessor :debug_score, :debug_aux
  def initialize; @s = {}; end
  def save_u32(i, v) = @s[i] = v
  def load_u32(i) = @s[i] || 0
end

Inputs = Struct.new(:keyboard)
Args = Struct.new(:inputs, :outputs, :audio, :gtk, :state)

module Kernel
  alias_method :orig_require, :require
  def require(p) = p.start_with?('app/') ? load(File.expand_path("../#{p}", __dir__)) : orig_require(p)
end

class Numeric; def to_radians = self * Math::PI / 180; end

load File.expand_path('../app/main.rb', __dir__)

class Sim
  attr_reader :args, :g, :sounds
  def initialize
    @args = Args.new(Inputs.new(KB.new), Outs.new, {}, Gtk.new, nil)
    @prev = {}
    @sounds = []
    $game = nil
    step
    @g = $game
  end

  def iv(n) = @g.instance_variable_get("@#{n}")
  def set(n, v) = @g.instance_variable_set("@#{n}", v)

  # held: array of button symbols held this frame
  def step(held = [], n = 1)
    n.times do
      kb = @args.inputs.keyboard
      Keys::NAMES.each do |k|
        on = held.include?(k)
        kb.send("#{k}=", on)
        kb.key_down.send("#{k}=", on && !@prev[k])
        @prev[k] = on
      end
      @args.outputs.clear
      tick(@args)
      @sounds.concat(@args.outputs.sounds.dup)
    end
    self
  end

  def snap = set(:cam, [[p.x - 560, 0].max, @g.max_cam].min.to_f)
  def p = iv(:p)
  def mode = iv(:mode)

  # get from title into play on level idx
  def start(level = 0)
    step([], 2); step([:start]); step([], 2)
    @g.instance_variable_set(:@level, level)
    @g.send(:to_intro)
    step([], 1) until mode == :play
    self
  end

  # walk into the arena, skip the warning, knock Rusty out, wait for the valve
  def beat_boss
    put(iv(:arena_c) + 3); step([], 2)
    step([], 1) while iv(:warning) > 0
    iv(:boss).data[:inv] = 0; @g.send(:boss_hit, 99); step([], 130)
    self
  end

  # teleport player to tile column (standing on the ground row 8)
  def put(col, row = 7)
    p.x = col * T + 12.0; p.y = @g.tile_bottom(row).to_f; p.vx = 0.0; p.vy = 0.0
    snap
    self
  end
end

$fails = 0
def check(name, cond)
  puts "#{cond ? 'PASS' : 'FAIL'}  #{name}"
  $fails += 1 unless cond
end

if __FILE__ == $0
  Dir[File.join(__dir__, 'scenarios', '*.rb')].sort.each { |f| load f }
  puts $fails.zero? ? 'ALL PASS' : "#{$fails} FAILED"
  exit($fails.zero? ? 0 : 1)
end
