# A linear congruential generator. The same seed gives the same numbers.
class Rng
  def initialize(seed)
    @state = seed & 0x7fffffff
  end

  # The next number, from 0 to 2**31 - 1.
  def next_int
    @state = (@state * 1103515245 + 12345) & 0x7fffffff
  end

  # The next number, from 0.0 up to 1.0.
  def rand01 = (next_int >> 8) / 8388608.0
end
