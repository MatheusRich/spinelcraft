# The text of world.sav and the bytes of its chunks. The first line is the
# version. Then each section has a line with its name and its fields. The
# line "chunks" has the key of each edited chunk, and the bytes of the chunks
# follow it, CHUNK_BYTES for each key. A save may lack a section, and a
# reader skips a section that it does not know. A new section needs no new
# version. The line "chunks" is not optional: a save that ends before it is
# cut off, and read refuses it. A game that saves again writes only the
# sections that it knows.
class SaveFile
  CHUNKS = "chunks"

  # The reason that read refused the save, or "".
  attr_reader :error, :chunks

  def initialize
    @sections = {}
    @chunks = {}
    @error = ""
  end

  # Sets the section name to the fields, written as text.
  def add(name, fields)
    @sections[name] = fields.map(&:to_s)
    nil
  end

  # The fields of the section name as text, or [] when the save lacks it. A
  # section always has a field.
  def section(name) = @sections.fetch(name, [])

  # The text before the chunks, for a save with the chunks of keys.
  def head(version, keys)
    text = "#{version}\n"
    @sections.each { |name, fields| text += "#{name} #{fields.join(" ")}\n" }
    "#{text}#{CHUNKS} #{keys.join(" ")}\n"
  end

  # Reads the sections and the chunks (by key) from data, and keeps the
  # reason in error when data is not a save of version. Gives true when it
  # reads the save.
  def read(data, version)
    first_end = data.index("\n")
    return reject("it has no first line") unless first_end

    format = data[0, first_end].split(" ").first.to_s
    return reject("its format is #{format}, not #{version}") if format != version

    read_sections(data, first_end + 1)
  end

  private

  def read_sections(data, start)
    at = start
    loop do
      line_end = data.index("\n", at)
      return reject("it has no line for the chunks") unless line_end

      fields = data[at, line_end - at].split(" ")
      at = line_end + 1
      return reject("it has an empty line") if fields.empty?

      name = fields.shift
      return read_chunks(data, fields, at) if name == CHUNKS

      @sections[name] = fields
    end
  end

  def read_chunks(data, keys, at)
    chunk_bytes = data.bytesize - at
    return reject("it has #{chunk_bytes} bytes of chunks, not #{keys.size} * #{CHUNK_BYTES}") if chunk_bytes != keys.size * CHUNK_BYTES

    keys.each_with_index { |key, index| @chunks[key.to_i] = data.byteslice(at + index * CHUNK_BYTES, CHUNK_BYTES) }
    true
  end

  def reject(reason)
    @error = reason
    false
  end
end
