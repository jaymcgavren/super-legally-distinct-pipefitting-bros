# The best score, kept in save slot 0.
class HighScore
  SLOT = 0

  attr_reader :value

  def initialize(gtk)
    @gtk = gtk
    @value = gtk.load_u32(SLOT) || 0
  end

  def submit(score)
    return unless score > @value
    @value = score
    @gtk.save_u32(SLOT, @value)
  end
end
