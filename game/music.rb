# Background music: OGG tracks in assets/music, from VoxeLibre (see
# assets/music/CREDITS.md). As in Minecraft, a track plays, then a long
# quiet gap comes before the next one.
class Music
  # The file of each track. The tracks before MINING play on the surface,
  # and the tracks from MINING on play underground.
  FILES = ["DarkReaven-calmed_cube", "Jester-Hailing_Forest", "exhale_and_tim_unwin-lonely_blossom",
           "Jester-Flock-of-One", "diminixed-pianowtune02", "DarkReaven-magic_of_the_forest",
           "DarkReaven-deep_mining", "Jester-0dd-BL0ck", "DarkReaven-beat_at_nightfall", "DarkReaven-watchful"]
  MINING = 6
  # The gain of each track in dB, in the order of FILES. It sets the
  # integrated loudness of each track to -23 LUFS, so that all tracks are
  # equally loud.
  GAINS = [-9.5, -6.7, -4.2, -6.3, -2.4, -8.1, -7.6, -5.4, -1.6, -4.5]
  # Seconds before the first track. Minecraft Java waits 100 ticks before
  # the first track; minecraft.wiki/w/Music does not confirm it.
  FIRST_WAIT = 5.0
  # Seconds of quiet after a track: 10 to 20 minutes. minecraft.wiki/w/Music
  GAP_MIN = 600.0
  GAP_MAX = 1200.0

  def initialize(seed)
    @rng = Rng.new(seed)
    @wait = FIRST_WAIT
    # The track that played last, or -1.
    @last = -1
    # A bag for each pool: the tracks that have yet to play in this round,
    # in a random order. The next track is the last one in the bag.
    @surface_bag = Array.new(0, 0)
    @mining_bag = Array.new(0, 0)
  end

  # Counts down the quiet gap while no track plays. Returns the track to
  # start now, or -1. Underground the track is a mining track. On the
  # surface no track starts at night, as in VoxeLibre (mcl_music).
  def next_track(dt, playing, underground, night)
    return -1 if playing
    @wait -= dt
    return -1 if @wait > 0.0 || (night && !underground)
    bag = underground ? @mining_bag : @surface_bag
    if bag.empty?
      underground ? fill(bag, MINING, FILES.size) : fill(bag, 0, MINING)
    end
    track = bag.pop
    @last = track
    @wait = GAP_MIN + @rng.rand01 * (GAP_MAX - GAP_MIN)
    track
  end

  # Puts the tracks from first up to (not with) stop in the bag, in a random
  # order. Each track plays once before a track plays again, and the first
  # track of a round is not the track that played last.
  def fill(bag, first, stop)
    (first...stop).each { |id| bag << id }
    i = bag.size - 1
    while i > 0
      j = (@rng.rand01 * (i + 1)).to_i
      t = bag[i]
      bag[i] = bag[j]
      bag[j] = t
      i -= 1
    end
    if bag.size > 1 && bag[bag.size - 1] == @last
      bag[bag.size - 1] = bag[0]
      bag[0] = @last
    end
  end

  # Starts track id. Returns false when its file does not open.
  def self.start(id) = Gfx.au_music_play("assets/music/#{FILES[id]}.ogg", GAINS[id]) == 0
end
