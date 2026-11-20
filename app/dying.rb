# A life lost: a beat, then the player hops and falls off the screen.
class Dying < Scene
  HOP_AT = 31
  HOP = 15.0
  FALL_GRAVITY = 0.8
  LENGTH = 190

  def name = :dying

  def update
    player = game.player
    if @frames >= HOP_AT
      player.vy = HOP if @frames == HOP_AT
      player.vy -= FALL_GRAVITY
      player.y += player.vy
    end
    game.update_effects
    game.vent_sounds
    return if @frames < LENGTH
    run.lives -= 1
    if run.lives <= 0
      game.finish(:gameover)
    else
      game.to_intro
    end
  end

  def draw
    game.draw_world(true)
  end
end
