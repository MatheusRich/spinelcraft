# Background music: OGG tracks in assets/music, from VoxeLibre (see
# assets/music/CREDITS.md). As in Minecraft, a track plays, then a long
# quiet gap comes before the next one.
class Music
  # The file of each track. The tracks before MINING play on the surface,
  # and the tracks from MINING on play underground.
  FILES = ["DarkReaven-calmed_cube", "Jester-Hailing_Forest", "exhale_and_tim_unwin-lonely_blossom",
           "Jester-Flock-of-One", "diminixed-pianowtune02", "DarkReaven-magic_of_the_forest",
           "DarkReaven-deep_mining", "Jester-0dd-BL0ck"]
  MINING = 6
  # The gain of each track in dB, in the order of FILES. It sets the
  # integrated loudness of each track to -23 LUFS, so that all tracks are
  # equally loud.
  GAINS = [-9.5, -6.7, -4.2, -6.3, -2.4, -8.1, -7.6, -5.4]
  # Seconds before the first track. Minecraft Java waits 100 ticks before
  # the first track; minecraft.wiki/w/Music does not confirm it.
  FIRST_WAIT = 5.0
  # Seconds of quiet after a track: 10 to 20 minutes. minecraft.wiki/w/Music
  GAP_MIN = 600.0
  GAP_MAX = 1200.0

  # The track that played last, or -1.
  attr_reader :last

  def initialize(seed)
    @rng = Rng.new(seed)
    @wait = FIRST_WAIT
    @last = -1
  end

  # Counts down the quiet gap while no track plays. Returns the track to
  # start now, or -1. Underground the track is a mining track. On the
  # surface no track starts at night, as in VoxeLibre (mcl_music).
  def next_track(dt, playing, underground, night)
    return -1 if playing
    @wait -= dt
    return -1 if @wait > 0.0 || (night && !underground)
    first = underground ? MINING : 0
    count = underground ? FILES.size - MINING : MINING
    track = first + (@rng.rand01 * count).to_i
    track = first + (track - first + 1) % count if track == @last
    @last = track
    @wait = GAP_MIN + @rng.rand01 * (GAP_MAX - GAP_MIN)
    track
  end

  # Starts track id. Returns false when its file does not open.
  def self.start(id) = Gfx.au_music_play("assets/music/#{FILES[id]}.ogg", GAINS[id]) == 0
end
