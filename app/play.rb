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
