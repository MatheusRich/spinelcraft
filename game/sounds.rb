# Sound effects, synthesized at start-up (22050 Hz mono floats).
module Sfx
  BREAK = 0
  PLACE = 1
  HURT = 2
  STEP = 3
  OINK = 4
  GROAN = 5
  HIT = 6
  SPLASH = 7
  SHOOT = 8
  DIG_STONE = 9
  DIG_WOOD = 10
  DIG_SOFT = 11
  POP = 12
  FIZZ = 13
  RATE = 22050.0

  def self.noise(state)
    (state * 1103515245 + 12345) & 0x7fffffff
  end

  # Low-passed noise with an exponential decay.
  def self.burst(seconds, decay, smooth, gain, seed)
    n = (seconds * RATE).to_i
    out = Array.new(n, 0.0)
    rng = seed
    lp = 0.0
    i = 0
    while i < n
      rng = noise(rng)
      white = (rng % 2000) / 1000.0 - 1.0
      lp += (white - lp) * smooth
      out[i] = lp * gain * Math.exp(-i / RATE * decay)
      i += 1
    end
    out
  end

  def self.tone(seconds, f0, f1, decay, shape, gain)
    n = (seconds * RATE).to_i
    out = Array.new(n, 0.0)
    phase = 0.0
    i = 0
    while i < n
      t = i / RATE
      f = f0 + (f1 - f0) * (i.to_f / n)
      phase += f / RATE
      frac = phase - phase.floor
      v = shape == 0 ? Math.sin(phase * 6.283185) : (frac * 2.0 - 1.0)
      attack = t < 0.01 ? t / 0.01 : 1.0
      out[i] = v * gain * attack * Math.exp(-t * decay)
      i += 1
    end
    out
  end

  def self.mix(a, b)
    n = a.size > b.size ? a.size : b.size
    out = Array.new(n, 0.0)
    i = 0
    while i < n
      out[i] = (i < a.size ? a[i] : 0.0) + (i < b.size ? b[i] : 0.0)
      i += 1
    end
    out
  end

  def self.load(id, samples)
    Gfx.au_load(id, samples, samples.size)
  end

  def self.init
    return false unless Gfx.au_init
    load(BREAK, burst(0.18, 22.0, 0.35, 0.9, 11))
    load(PLACE, mix(burst(0.07, 60.0, 0.25, 0.7, 12), tone(0.08, 150.0, 90.0, 40.0, 0, 0.5)))
    load(HURT, tone(0.22, 420.0, 180.0, 10.0, 1, 0.35))
    load(STEP, burst(0.06, 70.0, 0.15, 0.5, 13))
    oink = mix(tone(0.12, 260.0, 200.0, 12.0, 1, 0.25), tone(0.12, 520.0, 400.0, 14.0, 0, 0.15))
    load(OINK, mix(oink, Array.new(2600, 0.0) + oink))
    groan = mix(tone(0.7, 95.0, 70.0, 2.5, 1, 0.28), tone(0.7, 143.0, 100.0, 3.0, 0, 0.12))
    load(GROAN, groan)
    load(HIT, mix(burst(0.09, 45.0, 0.5, 0.8, 14), tone(0.09, 110.0, 60.0, 30.0, 0, 0.6)))
    load(SPLASH, burst(0.4, 7.0, 0.6, 0.6, 15))
    load(SHOOT, mix(burst(0.12, 35.0, 0.9, 0.4, 16), tone(0.1, 900.0, 500.0, 25.0, 0, 0.15)))
    load(DIG_STONE, mix(burst(0.05, 90.0, 0.8, 0.45, 17), tone(0.05, 700.0, 520.0, 70.0, 0, 0.35)))
    load(DIG_WOOD, mix(burst(0.06, 70.0, 0.3, 0.35, 18), tone(0.08, 230.0, 170.0, 45.0, 0, 0.6)))
    load(DIG_SOFT, burst(0.07, 55.0, 0.12, 0.9, 19))
    load(POP, tone(0.07, 600.0, 1150.0, 35.0, 0, 0.35))
    load(FIZZ, burst(0.45, 6.0, 0.9, 0.35, 20))
    true
  end
end
