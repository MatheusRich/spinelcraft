# A furnace: the slots for what it smelts, its fuel and its results, and
# the time that it has burned and smelted. It works one tick at a time, 20
# to a second, as in Minecraft.
class Furnace
  INPUT = 0
  FUEL = 1
  OUTPUT = 2
  # The ticks that one item takes to smelt. minecraft.wiki/w/Smelting
  SMELT_TICKS = 200
  # While the furnace is out, the progress on an item goes back this many
  # ticks for each tick. minecraft.wiki/w/Furnace (History, 14w02a and
  # 14w04a: "reverses at twice the speed of smelting"). The Block data part
  # of that page says that the progress resets to 0 instead.
  COOL_TICKS = 2

  attr_reader :x, :y, :z, :slots
  # The ticks of burn time left on the fuel item that burns, the burn time
  # of that whole item, and the ticks of progress on the item that smelts.
  attr_accessor :burn, :burn_total, :progress

  def initialize(x, y, z)
    @x = x
    @y = y
    @z = z
    @slots = Slots.new(3)
    @burn = 0
    @burn_total = 0
    @progress = 0
  end

  def lit? = @burn > 0

  # A furnace with nothing in it and no fire does not go into the save.
  def idle? = @burn == 0 && @progress == 0 && @slots.empty?(INPUT) && @slots.empty?(FUEL) && @slots.empty?(OUTPUT)

  # Advances one tick, as AbstractFurnaceBlockEntity does in Minecraft. out
  # and out_n are what the input smelts into (0 and 0 when it does not
  # smelt), and fuel is the burn time of the item in the fuel slot (0 when
  # it is not a fuel). A fuel item burns to its end, but a new one burns
  # only when there is something to smelt.
  def tick(out, out_n, fuel)
    @burn -= 1 if @burn > 0
    has_fuel = fuel > 0 && !@slots.empty?(FUEL)
    if lit? || (has_fuel && !@slots.empty?(INPUT))
      can = out > 0 && !@slots.empty?(INPUT) && fits?(out, out_n)
      if !lit? && can
        @burn = fuel
        @burn_total = fuel
        @slots.take(FUEL, 1)
      end
      if lit? && can
        @progress += 1
        if @progress >= SMELT_TICKS
          @progress = 0
          @slots.take(INPUT, 1)
          @slots.set(OUTPUT, out, @slots.count(OUTPUT) + out_n)
        end
      else
        @progress = 0
      end
    elsif @progress > 0
      @progress -= COOL_TICKS
      @progress = 0 if @progress < 0
    end
  end

  # True when n of b fit in the output slot.
  def fits?(b, n)
    @slots.empty?(OUTPUT) || (@slots.block(OUTPUT) == b && @slots.count(OUTPUT) + n <= Slots::STACK)
  end
end
