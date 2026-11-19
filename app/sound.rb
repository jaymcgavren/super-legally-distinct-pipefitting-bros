# Sound effects and music. Effects are one-shots on args.outputs.sounds, each
# played at most once per frame however many update steps ask for it; music
# is the controllable `:music` channel in args.audio.
class Sound
  MUSIC_GAIN = 0.375

  def initialize(args)
    @args = args
    @played = {}
  end

  # forget which effects played; call once per frame, before the updates
  def new_frame
    @played = {}
  end

  # sounds/<name>.wav, once per frame
  def play(name, gain = 1.0)
    return if @played[name]
    @played[name] = true
    path = "sounds/#{name}.wav"
    @args.outputs.sounds << (gain == 1.0 ? path : { path: path, gain: gain })
  end

  # the nut chime, `semitones` above its normal pitch, on its own channel so
  # each note cuts off the last
  def chime(semitones)
    @args.audio[:code] = { input: 'sounds/nut.wav', gain: 1.0, pitch: 2.0**(semitones / 12.0) }
  end

  # start sounds/<name>.wav on the music channel, replacing what was playing
  def music(name, looping: true)
    @args.audio.delete(:music)
    @args.audio[:music] = { input: "sounds/#{name}.wav", gain: MUSIC_GAIN, looping: looping }
  end

  def stop_music
    @args.audio.delete(:music)
  end

  # a non-looping track removes itself when it ends
  def music_playing? = !@args.audio[:music].nil?

  def pause_music = set_music(:paused, true)
  def resume_music = set_music(:paused, false)
  def music_pitch=(pitch)
    set_music(:pitch, pitch)
  end

  private

  def set_music(key, value)
    track = @args.audio[:music]
    track[key] = value if track
  end
end
