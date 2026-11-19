# The pad, read for the fixed-step updates. `poll` runs every host frame and
# latches presses; `read` runs at the start of every update step, takes a
# snapshot of what is held and consumes the latched presses. So a press on a
# frame with no update isn't lost, and a frame with several updates doesn't
# see it twice. Held state is read fresh each step.
#
# A is jump, B (or X) is run and throw, Start pauses.
class Controls
  PRESS_KEYS = %i[a b x start up down left right].freeze

  def initialize(args)
    @args = args
    @pressed = {}
  end

  def poll
    down = @args.inputs.keyboard.key_down
    PRESS_KEYS.each { |k| @pressed[k] = true if down.send(k) }
  end

  def read
    keyboard = @args.inputs.keyboard
    analog_x = keyboard.left_analog_x_perc || 0
    @left = keyboard.left || analog_x < -0.5
    @right = keyboard.right || analog_x > 0.5
    @jump_held = keyboard.a
    @run_held = keyboard.b || keyboard.x
    pressed = @pressed
    @jump_pressed = pressed[:a]
    @throw_pressed = pressed[:b] || pressed[:x]
    @start_pressed = pressed[:start]
    @left_pressed = pressed[:left]
    @right_pressed = pressed[:right]
    @code_press = if pressed[:up] then :up
                  elsif pressed[:down] then :down
                  elsif pressed[:left] then :left
                  elsif pressed[:right] then :right
                  end
    pressed.clear
  end

  # held this step
  def left? = @left
  def right? = @right
  def jump_held? = @jump_held
  def run_held? = @run_held

  # pressed since the last step
  def jump_pressed? = @jump_pressed
  def throw_pressed? = @throw_pressed
  def start_pressed? = @start_pressed
  def left_pressed? = @left_pressed
  def right_pressed? = @right_pressed
  # the d-pad direction pressed, for the secret code (:up wins a tie)
  attr_reader :code_press
end
