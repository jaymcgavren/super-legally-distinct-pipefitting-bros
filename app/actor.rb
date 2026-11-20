# Base class for things that move through the level: position, size,
# velocity, a state symbol and its timer.

class Actor
  attr_accessor :kind, :x, :y, :w, :h, :vx, :vy, :on_ground, :state, :timer, :facing,
                :active, :data, :previous_y, :riding

  def initialize(kind, x, y, w, h)
    @kind = kind
    @x = x.to_f
    @y = y.to_f
    @w = w
    @h = h
    @vx = 0.0
    @vy = 0.0
    @on_ground = false
    @state = :walk
    @timer = 0
    @facing = -1
    @active = false
    @data = {}
    @previous_y = @y
    @riding = nil
  end

  def dead? = @state == :dead
  def walking? = @state == :walk
  def gone? = @state == :gone
end
