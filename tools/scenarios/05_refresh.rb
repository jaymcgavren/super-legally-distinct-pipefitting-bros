# --- the game runs at the same speed whatever the display's refresh rate ---
# A script of [buttons held, 60 Hz steps]: title, start, run and jump, pause
# for a second, then run on.
REFRESH_SCRIPT = [[[], 10], [[:start], 2], [[], 200], [%i[right b], 120], [%i[right b a], 20],
                  [%i[right], 100], [[:start], 2], [[], 60], [[:start], 2], [%i[right], 60]]

# Play the script on a display of the given rate; snapshot the game after
# each part. Host frames per 60 Hz step = hz / 60 (whole numbers here).
def refresh_run(hz)
  s = Sim.new
  s.args.gtk.delta_ms = 1000.0 / hz
  snaps = REFRESH_SCRIPT.map do |held, steps|
    s.step(held, steps * hz / 60)    # e.g. 30 Hz: one frame per two steps
    [s.mode, s.iv(:frame), s.iv(:mode_t), s.p&.x&.round(3), s.p&.y&.round(3), s.iv(:score)]
  end
  [snaps, s.sounds.tally]
end

base, base_snd = refresh_run(60)
[30, 120].each do |hz|
  snaps, snd = refresh_run(hz)
  check "#{hz} Hz display: same game, step for step, as 60 Hz", snaps == base
  check "#{hz} Hz display: same sounds as 60 Hz", snd == base_snd
end

# 144 Hz isn't a whole number of frames per step: 10 seconds should still be
# 600 updates, give or take one
s = Sim.new
f0 = s.iv(:frame)
s.args.gtk.delta_ms = 1000.0 / 144
s.step([], 1440)
check '144 Hz display: 10 seconds is 600 updates', (s.iv(:frame) - f0 - 600).abs <= 1

# a tap that lands on a frame with no update still counts (120 Hz: every
# other frame has no update)
s = Sim.new
s.args.gtk.delta_ms = 1000.0 / 120
s.step([], 3)                       # leaves the next frame without an update
s.step([:start], 1); s.step([], 1)
check 'a one-frame tap on a frame with no update is not lost', s.mode == :intro

# a stall (window dragged, tab hidden) catches up at most 4 steps, no spiral
s = Sim.new
f0 = s.iv(:frame)
s.args.gtk.delta_ms = 5000.0
s.step([], 1)
check 'a 5 second stall runs at most 4 updates', s.iv(:frame) - f0 == 4
