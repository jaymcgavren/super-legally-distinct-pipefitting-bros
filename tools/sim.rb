# Headless gameplay harness: runs app/main.rb under host Ruby with a stub
# `args`, so scenarios can be scripted and asserted (Minitest).  ruby tools/sim.rb
$LOAD_PATH.unshift File.expand_path('..', __dir__)

class Keys
  NAMES = %i[left right up down a b x y start select].freeze
  attr_accessor(*NAMES, :left_analog_x_perc)

  def initialize = NAMES.each { |n| send("#{n}=", false) }
end

class KB < Keys
  attr_accessor :key_down

  def initialize
    super
    @key_down = Keys.new
  end
end

class Outs
  attr_accessor :background_color

  def initialize = @h = Hash.new { |h, k| h[k] = [] }
  def method_missing(n, *_a) = n.to_s.end_with?('=') ? nil : @h[n]
  def respond_to_missing?(*) = true
  def [](k) = (@t ||= {})[k] ||= Outs.new

  def clear
    @h.clear
    @t&.each_value(&:clear)
  end
end

class Gtk
  # delta_ms: the host frame time handed to the game (60 Hz unless a test sets it)
  attr_accessor :debug_score, :debug_aux, :delta_ms

  def initialize
    @s = {}
    @delta_ms = 1000.0 / 60
  end

  def save_u32(i, v) = @s[i] = v
  def load_u32(i) = @s[i] || 0
end

Inputs = Struct.new(:keyboard)
Args = Struct.new(:inputs, :outputs, :audio, :gtk, :state)

module Kernel
  alias orig_require require
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
  def level = iv(:level)
  def run = iv(:run)

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

  def snap = iv(:camera).jump_to(p.x - 560)
  def p = iv(:player)
  def mode = @g.mode
  # steps since the current scene began
  def mode_frames = @g.scene.frames
  def scene_iv(n) = @g.scene.instance_variable_get("@#{n}")

  # get from title into play on level idx
  def start(level = 0)
    step([], 2); step([:start]); step([], 2)
    @g.instance_variable_set(:@level_index, level)
    @g.send(:to_intro)
    step([], 1) until mode == :play
    self
  end

  # walk into the arena, skip the warning, knock Rusty out, wait for the valve
  def beat_boss
    put(iv(:arena_column) + 3); step([], 2)
    step([], 1) while iv(:warning) > 0
    iv(:boss).invulnerable = 0; @g.send(:boss_hit, 99); step([], 130)
    self
  end

  # teleport player to tile column (standing on the ground row 8)
  def put(col, row = 7)
    p.x = col * TILE + 12.0; p.y = level.tile_bottom(row).to_f; p.vx = 0.0; p.vy = 0.0
    snap
    self
  end
end

# A scenario calls `check name, condition` for each thing it pins down. It
# prints PASS/FAIL and counts as a Minitest assertion, but a failure doesn't
# stop the scenario: the rest of its checks still run, and the test fails
# at the end listing every failed check.
$fails = 0
def check(name, cond)
  puts "#{cond ? 'PASS' : 'FAIL'}  #{name}"
  return unless $scenario
  $scenario.assertions += 1
  $scenario.failed_checks << name unless cond
  $fails += 1 unless cond
end

if __FILE__ == $PROGRAM_NAME
  # ruby tools/sim.rb                  every scenario
  # ruby tools/sim.rb -n test_02_boss  one scenario (any Minitest option works)
  require 'minitest/autorun'

  # One test per file in tools/scenarios, run in file order.
  class ScenarioTest < Minitest::Test
    def self.run_order = :alpha

    def failed_checks = (@failed_checks ||= [])

    Dir[File.join(__dir__, 'scenarios', '*.rb')].each do |file|
      name = File.basename(file, '.rb')
      define_method("test_#{name}") do
        puts "\n== #{name}"   # own line: Minitest's progress dot ends the last one
        $scenario = self   # read by the top-level check
        load file
        assert failed_checks.empty?, "failed checks:\n  #{failed_checks.join("\n  ")}"
      ensure
        $scenario = nil
      end
    end
  end

  Minitest.after_run { puts $fails.zero? ? 'ALL PASS' : "#{$fails} FAILED" }
end
