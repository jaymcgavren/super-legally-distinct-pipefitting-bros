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
