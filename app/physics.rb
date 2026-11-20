# Tile collision and gravity, for anything with x, y, w, h, vx, vy (Actor).
# Mixed into Game: it reads the level grid from @level and the moving
# platforms from @lifts.
module Physics
  GRAVITY_HOLD = 0.65   # rising with jump held
  GRAVITY_CUT  = 1.6    # rising, jump let go: cuts the jump short
  GRAVITY_FALL = 1.0    # falling, and everything that isn't the player
  FALL_MAX     = -15.0  # terminal velocity

  # gravity with the terminal-velocity cap
  def fall(actor)
    actor.vy -= GRAVITY_FALL
    actor.vy = FALL_MAX if actor.vy < FALL_MAX
  end

  def box_free?(x, y, w, h)
    r0 = @level.row_at(y + h - 0.01)
    r1 = @level.row_at(y + 0.01)
    c0 = @level.column_at(x + 0.01)
    c1 = @level.column_at(x + w - 0.01)
    r0.upto(r1) { |r| c0.upto(c1) { |c| return false if SOLID[@level.cell(c, r)] } }
    true
  end

  def overlap?(a, b)
    a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y
  end

  def rect_hit?(actor, x, y, w, h)
    actor.x < x + w && actor.x + actor.w > x && actor.y < y + h && actor.y + actor.h > y
  end

  # horizontal move with tile collision; returns true on wall hit
  def move_x(actor)
    actor.x += actor.vx
    r0 = @level.row_at(actor.y + actor.h - 0.01)
    r1 = @level.row_at(actor.y + 0.01)
    if actor.vx > 0
      c = @level.column_at(actor.x + actor.w - 0.01)
      r0.upto(r1) do |r|
        next unless SOLID[@level.cell(c, r)]
        actor.x = c * TILE - actor.w
        return true
      end
    elsif actor.vx < 0
      c = @level.column_at(actor.x)
      r0.upto(r1) do |r|
        next unless SOLID[@level.cell(c, r)]
        actor.x = (c + 1) * TILE
        return true
      end
    end
    false
  end

  # vertical move; lands on solids, one-way pipes and lifts. Returns the
  # list of [col, row] cells hit by the head (empty if none).
  def move_y(actor, use_lifts, corner_fix)
    previous_y = actor.y
    actor.y += actor.vy
    actor.on_ground = false
    actor.riding = nil
    c0 = @level.column_at(actor.x + 0.01)
    c1 = @level.column_at(actor.x + actor.w - 0.01)
    return head_hits(actor, previous_y, c0, c1, corner_fix) if actor.vy > 0
    land_on_tiles(actor, previous_y, c0, c1)
    land_on_lift(actor, previous_y) if use_lifts && !actor.on_ground
    []
  end

  # falling (or standing): stop on a solid tile, or on a one-way pipe if
  # the feet were above it before this step
  def land_on_tiles(actor, previous_y, c0, c1)
    r = @level.row_at(actor.y)
    top = @level.tile_top(r)
    c0.upto(c1) do |c|
      tile = @level.cell(c, r)
      next unless SOLID[tile] || (tile == '-' && previous_y >= top - 0.01)
      actor.y = top
      actor.vy = 0.0
      actor.on_ground = true
      break
    end
  end

  # a lift catches feet that crossed its top this step (with some slack)
  def land_on_lift(actor, previous_y)
    @lifts.each do |lift|
      lift_top = lift.y + lift.h
      over = actor.x + actor.w > lift.x + 4 && actor.x < lift.x + lift.w - 4
      next unless over && actor.y <= lift_top && previous_y >= lift_top - 14
      actor.y = lift_top
      actor.vy = 0.0
      actor.on_ground = true
      actor.riding = lift
      break
    end
  end

  # rising: the head stops under solid tiles (and hidden crates it started
  # below). Returns the [col, row] cells hit, or [] if it got past.
  def head_hits(actor, previous_y, c0, c1, corner_fix)
    r = @level.row_at(actor.y + actor.h)
    hits = []
    c0.upto(c1) do |c|
      tile = @level.cell(c, r)
      hits << c if SOLID[tile] || tile == 'I'
    end
    return hits if hits.empty?
    # a hidden crate only blocks if the head started below it
    hits = hits.select { |c| @level.cell(c, r) != 'I' || previous_y + actor.h <= @level.tile_bottom(r) + 0.01 }
    return hits if hits.empty?
    return [] if corner_fix && hits.size == 1 && slip_past_corner(actor, hits[0])
    actor.y = @level.tile_bottom(r) - actor.h
    actor.vy = 0.0
    hits.map { |c| [c, r] }
  end

  # Clipping a single tile by its corner nudges the actor sideways (up to
  # 18 px) past it instead of stopping the jump. Returns whether it did.
  def slip_past_corner(actor, c)
    left_over = actor.x + actor.w - c * TILE
    right_over = (c + 1) * TILE - actor.x
    if left_over <= 18 && box_free?(actor.x - left_over, actor.y, actor.w, actor.h)
      actor.x -= left_over
      true
    elsif right_over <= 18 && box_free?(actor.x + right_over, actor.y, actor.w, actor.h)
      actor.x += right_over
      true
    else
      false
    end
  end
end
