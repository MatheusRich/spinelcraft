# The trees that the generator grows, and the trees that grow from
# saplings. A tree has the shape of its wood and its biome. The generator
# writes each tree through World#put and World#air_in?, which keep each
# block inside its chunk. A sapling plans its tree from World#get.
class Trees
  # The shortest trunk of each tree kind (Biome::OAK and so on), one
  # entry for each of Biome::TREE_KINDS.
  TRUNK = [4, 5, 5, 4]
  # The wood of each tree kind (Block::OAK_WOOD and so on). The game has no
  # acacia or jungle wood, so those trees have oak wood.
  WOOD = [Block::OAK_WOOD, Block::SPRUCE_WOOD, Block::OAK_WOOD, Block::OAK_WOOD]
  # How far leaves reach from the root of a tree: a giant jungle tree
  # grows a branch 5 blocks long, and the leaves at its end reach 3 more.
  TREE_REACH = 8
  # Large oaks per 65536 oak saplings. minecraft.wiki/w/Oak gives 1 in 10
  # for Alpha, "including from saplings".
  SAPLING_LARGE_OAKS = 6554
  # Large oaks, jungle bushes and giant jungle trees per 65536 jungle
  # trees: 10%, 45% and 15%. The rest are small jungle trees (see jungle).
  JUNGLE_LARGE_OAKS = 6554
  JUNGLE_BUSHES = 29491
  JUNGLE_GIANTS = 9830
  # Corner leaves per 65536 that an oak and a jungle bush leave out. The
  # wiki does not give these numbers.
  OAK_GAPS = 32000
  BUSH_GAPS = 32768

  def initialize(world)
    @world = world
    # The corner of the chunk that the generator makes (see tree).
    @x0 = 0
    @z0 = 0
    # The log and the leaves of the tree that the generator grows (see use_wood).
    @log = Block::OAK_LOG
    @leaves = Block::OAK_LEAVES
    # A tree that grows from a sapling (see plan_tree): its changes as x, y,
    # z, block quads, and the keys of the cells that they change.
    @planning = false
    @plan = Array.new(0, 0)
    @plan_cells = {}
    @plan_blocked = false
    nil
  end

  # Writes block at x, y, z when it is inside the chunk that the generator
  # makes (see World#put). While plan_tree plans a tree, it adds the
  # block to the plan instead.
  def put(x, y, z, block)
    return plan(x, y, z, block) if @planning

    @world.put(x, y, z, block, @x0, @z0)
  end

  # True when x, y, z is air. While plan_tree plans a tree, it looks at
  # the loaded world and at the plan.
  def air_in?(x, y, z)
    return !@plan_cells.key?(World.key(x, y, z)) && @world.get(x, y, z) == Block::AIR if @planning

    @world.air_in?(x, y, z, @x0, @z0)
  end

  # Puts leaves at x, y, z when it is air.
  def leaf(x, y, z)
    put(x, y, z, @leaves) if air_in?(x, y, z)
    nil
  end

  # The changes of a tree of wood (Block::OAK_WOOD and so on) that grows
  # from the sapling at x, y, z, as x, y, z, block quads. The tree has the
  # shape of the generator's tree of its wood. Unlike the generator, it
  # only replaces air, leaves and plants, so it does not break what the
  # player built. The list is empty when something else is in the way of
  # a log.
  def plan_tree(gx, gy, gz, wood)
    # The shapes keep Integer positions, as World#get does (see World.index).
    x = gx.to_i
    y = gy.to_i
    z = gz.to_i
    @planning = true
    @plan = Array.new(0, 0)
    @plan_cells = {}
    @plan_blocked = false
    use_wood(wood)
    if wood == Block::SPRUCE_WOOD
      spruce(x, y, z)
    elsif wood == Block::BIRCH_WOOD
      birch(x, y, z)
    else
      oak_or_large(x, y, z, SAPLING_LARGE_OAKS)
    end
    @planning = false
    @plan_blocked ? Array.new(0, 0) : @plan
  end

  # Adds block at x, y, z to the tree that plan_tree grows. A log blocks
  # the tree when the cell holds something other than air, leaves or a
  # plant, and dirt only replaces grass.
  def plan(x, y, z, block)
    old = @world.get(x, y, z)
    if block == Block::DIRT
      return unless old == Block::GRASS || old == Block::SNOW_GRASS
    elsif Block.log?(block) && !(old == Block::AIR || Block.leaves?(old) || Block.plant?(old))
      @plan_blocked = true
      return
    end
    @plan_cells[World.key(x, y, z)] = block
    @plan << x << y << z << block
  end

  # A tree of the biome on the ground below x, y, z, with the blocks
  # that are inside chunk x0, z0. The biome picks the kind of tree
  # (Biome::TREE), and the kind picks among its shapes.
  def tree(x, y, z, x0, z0, biome)
    @x0 = x0
    @z0 = z0
    kind = Biome::TREE[biome]
    use_wood(WOOD[kind])
    if kind == Biome::ACACIA
      acacia(x, y, z)
    elsif kind == Biome::SPRUCE
      Noise.hash3(x, y, z, 31) < Biome::PINES[biome] ? pine(x, y, z) : spruce(x, y, z)
    elsif kind == Biome::JUNGLE_TREE
      jungle(x, y, z)
    elsif Noise.hash3(x, y, z, 32) < Biome::BIRCHES[biome]
      use_wood(Block::BIRCH_WOOD)
      birch(x, y, z)
    else
      oak_or_large(x, y, z, Biome::LARGE_OAKS[biome])
    end
    nil
  end

  # A birch on the ground below x, y, z: an oak with a trunk of 5 to 7
  # logs. Birches "grow to be 5 to 7 blocks tall" (minecraft.wiki/w/Birch).
  def birch(x, y, z)
    oak(x, y, z, 5 + Noise.hash3(x, y, z, 23) % 3)
    nil
  end

  # A large oak on the ground below x, y, z, with a chance of large_oaks
  # in 65536, else an oak.
  def oak_or_large(x, y, z, large_oaks)
    if Noise.hash3(x, y, z, 28) < large_oaks
      large_oak(x, y, z)
    else
      oak(x, y, z, TRUNK[Biome::OAK] + Noise.hash3(x, y, z, 23) % 3)
    end
    nil
  end

  # The trees that the generator grows next have the log and the leaves of
  # wood (Block::OAK_WOOD and so on).
  def use_wood(wood)
    @log = Block::LOGS[wood]
    @leaves = Block::LEAVES[wood]
  end

  # An oak on the ground below x, y, z: a trunk of tall logs under two
  # wide layers and two small layers of leaves, with some corners missing.
  # Small jungle trees have this shape too.
  def oak(x, y, z, tall)
    return if y + tall + 2 >= WY

    logs(x, y, z, tall)
    top = y + tall
    (top - 2..top + 1).each do |ly|
      radius = ly >= top ? 1 : 2
      square(radius) do |dx, dz|
        corner = dx.abs == radius && dz.abs == radius
        skip = corner && (ly == top + 1 || Noise.hash3(x + dx, ly, z + dz, 24) < OAK_GAPS)
        leaf(x + dx, ly, z + dz) unless skip
      end
    end
  end

  # A tree of the jungle on the ground below x, y, z: a large oak, a bush,
  # a giant jungle tree or a small jungle tree. minecraft.wiki/w/Jungle
  # names them all, and says that the oaks there are "more commonly
  # large". The wiki does not confirm the shares of 10%, 45%, 15% and 30%:
  # they copy the jungle trees in the game code.
  def jungle(x, y, z)
    r = Noise.hash3(x, y, z, 28)
    if r < JUNGLE_LARGE_OAKS
      large_oak(x, y, z)
    elsif r < JUNGLE_LARGE_OAKS + JUNGLE_BUSHES
      jungle_bush(x, y, z)
    elsif r < JUNGLE_LARGE_OAKS + JUNGLE_BUSHES + JUNGLE_GIANTS
      giant_jungle_tree(x, y, z)
    else
      # The trunk "can extend up to 10 blocks tall" (minecraft.wiki/w/Jungle_tree).
      oak(x, y, z, TRUNK[Biome::JUNGLE_TREE] + Noise.hash3(x, y, z, 23) % 7)
    end
  end

  # A jungle bush on the ground below x, y, z: one log, in 3 layers of
  # leaves that reach 3, 2 and 1 blocks out from the bottom up, with some
  # corners missing. minecraft.wiki/w/Jungle_Bush says "1-2 jungle logs"
  # in "1-3 layers" of leaves. The wiki does not confirm the reach: it
  # copies the bush in the game code.
  def jungle_bush(x, y, z)
    return if y + 3 >= WY

    logs(x, y, z, 1)
    3.times do |ly|
      radius = 3 - ly
      square(radius) do |dx, dz|
        skip = dx.abs == radius && dz.abs == radius && Noise.hash3(x + dx, y + ly, z + dz, 24) < BUSH_GAPS
        leaf(x + dx, y + ly, z + dz) unless skip
      end
    end
  end

  # A giant jungle tree on the ground below x, y, z: a trunk of 2 x 2 logs
  # with a wide crown on top, and branches in its upper half that end in
  # small crowns. minecraft.wiki/w/Jungle_tree says that they "can grow up
  # to 32 blocks high", with "between one and six branches". The wiki does
  # not confirm the other numbers: they copy the mega jungle tree in the
  # game code.
  def giant_jungle_tree(x, y, z)
    r = Noise.hash3(x, y, z, 23)
    tall = 10 + r % 3 + r / 3 % 20
    return if y + tall >= WY

    # Each log of the 2 x 2 trunk goes down to the ground of its own column.
    4.times do |a|
      cx = x + a % 2
      cz = z + a / 2
      ground = a == 0 ? y : [y, @world.terrain.surface_height(cx, cz)].min
      logs(cx, ground, cz, y + tall - ground)
    end
    jungle_crown(x, y + tall, z, 3, 3, true)
    i = tall - 2 - r / 60 % 4
    while i > tall / 2
      angle = Noise.fraction(x, y + i, z, 29) * 2.0 * Math::PI
      bx = 0
      bz = 0
      5.times do |l|
        bx = (1.5 + Math.cos(angle) * l).to_i
        bz = (1.5 + Math.sin(angle) * l).to_i
        put(x + bx, y + i - 3 + l / 2, z + bz, @log)
      end
      b = Noise.hash3(x, y + i, z, 30)
      jungle_crown(x + bx, y + i, z + bz, 1, 2 + b % 2, false)
      i -= 2 + b / 2 % 4
    end
  end

  # The crown of a giant jungle tree: layers of leaves from x, y, z down,
  # that reach r blocks, then r + 1 and so on. Each layer is round, and
  # dx + dz stays below 7. A wide crown is around the 2 x 2 trunk that x,
  # z is the corner of.
  def jungle_crown(x, y, z, r, layers, wide)
    w = wide ? 1 : 0
    layers.times do |i|
      reach = r + i
      (-reach..reach + w).each do |dx|
        (-reach..reach + w).each do |dz|
          ax = dx.abs
          az = dz.abs
          ax = (dx - 1).abs if wide && dx > 0
          az = (dz - 1).abs if wide && dz > 0
          leaf(x + dx, y - i, z + dz) if ax + az < 7 && ax * ax + az * az <= reach * reach
        end
      end
    end
  end

  # A spruce on the ground below x, y, z: a trunk of 5 to 8 logs with 1
  # or 2 bare logs at the bottom. From the top down, the layers of leaves
  # grow wider and then narrow again, and each narrow layer is wider than
  # the narrow layer above it, up to a widest reach of 2 or 3. The top
  # layer is 0 to 2 blocks above the trunk. minecraft.wiki/w/Spruce says
  # that "the leaves tend to grow in discrete rows". The wiki does not
  # confirm the numbers: they copy the spruce feature in the game code.
  def spruce(x, y, z)
    r = Noise.hash3(x, y, z, 23)
    tall = TRUNK[Biome::SPRUCE] + r % 3 + r / 3 % 2
    r /= 6
    bare = 1 + r % 2
    widest = 2 + r / 2 % 2
    above = r / 4 % 3
    reach = r / 12 % 2
    return if y + tall + above >= WY

    logs(x, y, z, tall)
    top = y + tall
    low = top - [4, tall - bare].max
    step = 1
    narrow = 0
    (top + above).downto(low) do |ly|
      leaf_row(x, ly, z, reach)
      if reach >= step
        reach = narrow
        narrow = 1
        step = [step + 1, widest].min
      else
        reach += 1
      end
    end
  end

  # A pine on the ground below x, y, z: a tall bare trunk of 6 to 10 logs
  # with a few small layers of leaves at the top. minecraft.wiki/w/Spruce
  # says that pines are "a fairly tall variant of spruces" "with only a
  # few leaves at the top". The wiki does not confirm the numbers: they
  # copy the pine feature in the game code.
  def pine(x, y, z)
    r = Noise.hash3(x, y, z, 23)
    tall = 6 + r % 5
    layers = 4 + r / 5 % 2
    return if y + tall + 1 >= WY

    logs(x, y, z, tall)
    top = y + tall
    layers.times { |i| leaf_row(x, top + 1 - i, z, i == 0 || i == layers - 1 ? 0 : 1) }
  end

  # A trunk of tall logs up from x, y, z, on dirt.
  def logs(x, y, z, tall)
    tall.times { |i| put(x, y + i, z, @log) }
    put(x, y - 1, z, Block::DIRT)
  end

  # A square layer of leaves around x, y, z that reaches out r blocks,
  # without its corners.
  def leaf_row(x, y, z, r)
    square(r) { |dx, dz| leaf(x + dx, y, z + dz) if dx.abs < r || dz.abs < r || r == 0 }
  end

  # Yields each dx, dz of the square that reaches r blocks out from its
  # middle.
  def square(r)
    (-r..r).each { |dx| (-r..r).each { |dz| yield dx, dz } }
    nil
  end

  # A large oak on the ground below x, y, z: a tall trunk with a branch on
  # most layers of its upper part, and a ball of leaves at the top and at
  # the end of each branch. minecraft.wiki/w/Oak says only that "they
  # often have branches", and that the sapling needs 4 to 14 blocks of
  # space. The heights and the branch lengths copy the fancy trunk in the
  # game code. The wiki does not confirm them.
  def large_oak(x, y, z)
    tall = 5 + Noise.hash3(x, y, z, 23) % 12
    return if y + tall >= WY

    trunk = (tall * 0.618).floor
    limb(x, y, z, x, y + trunk, z)
    limb(x, y + trunk, z, x, y + tall - 5, z)
    oak_ball(x, y + tall - 5, z)
    put(x, y - 1, z, Block::DIRT)
    (tall - 5).downto(0) do |n|
      spread = large_oak_spread(tall, n)
      if spread >= 0.0
        reach = spread * (Noise.fraction(x, y + n, z, 29) + 0.328)
        angle = Noise.fraction(x, y + n, z, 30) * 2.0 * Math::PI
        ex = x + (reach * Math.sin(angle) + 0.5).floor
        ez = z + (reach * Math.cos(angle) + 0.5).floor
        ey = y + n - 1
        # The branch rises from the trunk by about 2 blocks for each 5 out.
        rise = ey - Math.sqrt(((x - ex) * (x - ex) + (z - ez) * (z - ez)).to_f) * 0.381
        base = rise > y + trunk ? y + trunk : rise.to_i
        # Branches that start low on the trunk do not grow.
        if base - y >= tall * 0.2
          limb(x, base, z, ex, ey, ez)
          oak_ball(ex, ey, ez)
        end
      end
    end
  end

  # How far out a large oak that is tall blocks high grows the branch at
  # n blocks above the ground, or -1.0 below 30% of its height. Branches
  # are longest at half the height, so the crown is round.
  def large_oak_spread(tall, n)
    return -1.0 if n < tall * 0.3

    half = tall / 2.0
    d = half - n
    return 0.0 if d.abs >= half

    Math.sqrt(half * half - d * d) * 0.5
  end

  # A straight line of logs from one block to another, both included.
  def limb(sx, sy, sz, ex, ey, ez)
    dx = ex - sx
    dy = ey - sy
    dz = ez - sz
    steps = [dx.abs, dy.abs, dz.abs].max
    (0..steps).each do |i|
      t = steps == 0 ? 0.0 : i.to_f / steps
      put(sx + (0.5 + t * dx).floor, sy + (0.5 + t * dy).floor, sz + (0.5 + t * dz).floor, @log)
    end
  end

  # A ball of leaves 5 blocks tall on the end of a large oak branch at x,
  # y, z. A layer keeps each block whose far corner is within r of the
  # branch end: a plus at the bottom and at the top (r = 2), and 5 x 5
  # without the corners between them (r = 3).
  def oak_ball(x, y, z)
    (0..4).each do |ly|
      r = ly == 0 || ly == 4 ? 2 : 3
      square(r) do |dx, dz|
        ax = dx.abs + 0.5
        az = dz.abs + 0.5
        leaf(x + dx, y + ly, z + dz) if ax * ax + az * az <= r * r
      end
    end
  end

  # An acacia on the ground below x, y, z. Near its top, the trunk leans
  # 1 to 3 blocks to one side. Most acacias also fork a shorter branch
  # that grows out on a diagonal, with a smaller crown.
  # minecraft.wiki/w/Tree_definition (forking_trunk_placer) gives this
  # shape. The wiki does not confirm the heights and the odds: they copy
  # the acacia feature in the game code.
  def acacia(x, y, z) # rubocop:todo Metrics/MethodLength
    r = Noise.hash3(x, y, z, 23)
    tall = TRUNK[Biome::ACACIA] + r % 3 + r / 3 % 3
    return if y + tall + 2 >= WY

    r /= 9
    dir = r % 4
    bend = tall - 1 - r / 4 % 4
    lean = 3 - r / 16 % 3
    tx = x
    tz = z
    tall.times do |i|
      if i >= bend && lean > 0
        tx += Block::DIR_DX[dir]
        tz += Block::DIR_DZ[dir]
        lean -= 1
      end
      put(tx, y + i, tz, @log)
    end
    put(x, y - 1, z, Block::DIRT)
    r = Noise.hash3(x, y, z, 27)
    side = r % 4
    if side != dir
      i = bend - 1 - r / 4 % 2
      left = 1 + r / 8 % 3
      bx = x
      bz = z
      top = -1
      while i < tall && left > 0
        if i >= 1
          bx += Block::DIR_DX[side]
          bz += Block::DIR_DZ[side]
          put(bx, y + i, bz, @log)
          top = y + i
        end
        i += 1
        left -= 1
      end
      acacia_crown(bx, top, bz, 2) if top >= 0
    end
    acacia_crown(tx, y + tall - 1, tz, 3)
  end

  # The flat crown of an acacia on the log at x, y, z. Level with the
  # log, the leaves reach out `reach` blocks, without the corners. One
  # layer above, they cover the 3 x 3 blocks over the log, and a crown
  # that reaches 3 adds one block at the middle of each side.
  def acacia_crown(x, y, z, reach)
    leaf_row(x, y, z, reach)
    square(reach) do |dx, dz|
      ax = dx.abs
      az = dz.abs
      leaf(x + dx, y + 1, z + dz) if (ax <= 1 && az <= 1) || ax + az < reach
    end
  end
end
