# Perlin noise, and a hash for random choices that a position decides.
class Noise
  def initialize(seed)
    p = (0...256).to_a
    rng = Rng.new(seed)
    255.downto(1) do |i|
      j = rng.next_int % (i + 1)
      t = p[i]
      p[i] = p[j]
      p[j] = t
    end
    @perm = Array.new(512, 0)
    512.times { |i| @perm[i] = p[i & 255] }
  end

  def fade(t) = t * t * t * (t * (t * 6.0 - 15.0) + 10.0)

  def grad2(h, x, y)
    case h & 7
    when 0 then x + y
    when 1 then -x + y
    when 2 then x - y
    when 3 then -x - y
    when 4 then x
    when 5 then -x
    when 6 then y
    else -y
    end
  end

  def grad3(h, x, y, z)
    case h & 15
    when 0, 12 then x + y
    when 1, 14 then -x + y
    when 2 then x - y
    when 3 then -x - y
    when 4 then x + z
    when 5 then -x + z
    when 6 then x - z
    when 7 then -x - z
    when 8 then y + z
    when 9, 13 then -y + z
    when 10 then y - z
    else -y - z
    end
  end

  def noise2(x, y)
    xi = x.floor
    yi = y.floor
    xf = x - xi
    yf = y - yi
    xa = xi & 255
    ya = yi & 255
    u = fade(xf)
    v = fade(yf)
    aa = @perm[@perm[xa] + ya]
    ab = @perm[@perm[xa] + ya + 1]
    ba = @perm[@perm[xa + 1] + ya]
    bb = @perm[@perm[xa + 1] + ya + 1]
    gaa = grad2(aa, xf, yf)
    gab = grad2(ab, xf, yf - 1.0)
    x1 = gaa + (grad2(ba, xf - 1.0, yf) - gaa) * u
    x2 = gab + (grad2(bb, xf - 1.0, yf - 1.0) - gab) * u
    (x1 + (x2 - x1) * v) * 0.7
  end

  def noise3(x, y, z)
    xi = x.floor
    yi = y.floor
    zi = z.floor
    xf = x - xi
    yf = y - yi
    zf = z - zi
    xa = xi & 255
    ya = yi & 255
    za = zi & 255
    u = fade(xf)
    v = fade(yf)
    w = fade(zf)
    a = @perm[xa] + ya
    aa = @perm[a] + za
    ab = @perm[a + 1] + za
    b = @perm[xa + 1] + ya
    ba = @perm[b] + za
    bb = @perm[b + 1] + za
    l1 = lerp(lerp(grad3(@perm[aa], xf, yf, zf), grad3(@perm[ba], xf - 1.0, yf, zf), u),
              lerp(grad3(@perm[ab], xf, yf - 1.0, zf), grad3(@perm[bb], xf - 1.0, yf - 1.0, zf), u), v)
    l2 = lerp(lerp(grad3(@perm[aa + 1], xf, yf, zf - 1.0), grad3(@perm[ba + 1], xf - 1.0, yf, zf - 1.0), u),
              lerp(grad3(@perm[ab + 1], xf, yf - 1.0, zf - 1.0), grad3(@perm[bb + 1], xf - 1.0, yf - 1.0, zf - 1.0), u), v)
    lerp(l1, l2, w)
  end

  def lerp(a, b, t) = a + (b - a) * t

  def fbm2(x, y, octaves)
    sum = 0.0
    amp = 1.0
    freq = 1.0
    norm = 0.0
    octaves.times do
      sum += noise2(x * freq, y * freq) * amp
      norm += amp
      # `x *= k` in a loop makes Spinel box x as a possible bigint.
      amp /= 2.0
      freq += freq
    end
    sum / norm
  end

  # A number from 0 to 0xffff for the cell x, y, z. Each salt gives other numbers.
  def self.hash3(x, y, z, salt)
    h = (x * 73856093 + y * 19349663 + z * 83492791 + salt * 2654435761) & 0xffffffff
    h = ((h ^ (h >> 15)) * 2146121005) & 0xffffffff
    h = ((h ^ (h >> 13)) * 1798096565) & 0xffffffff
    (h ^ (h >> 16)) & 0xffff
  end

  # hash3 as a fraction from 0.0 up to 1.0, without 1.0.
  def self.fraction(x, y, z, salt) = hash3(x, y, z, salt) / 65536.0
end
