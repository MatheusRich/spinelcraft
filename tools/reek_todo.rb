# Makes the exclude lists of .reek.yml again: for each detector, the
# methods that have an offense now. The comments at the top of the file
# stay. Run it with `mise exec -- ruby tools/reek_todo.rb`.
require "json"
require "open3"
require "tempfile"
require "yaml"

path = File.expand_path("../.reek.yml", __dir__)
text = File.read(path)
header = text.lines.take_while { |line| line.start_with?("#") }.join
config = YAML.safe_load(text)
config["detectors"].each_value { |detector| detector.delete("exclude") }
# The copy sits beside .reek.yml, because Reek finds exclude_paths from the
# folder of its configuration.
smells = Tempfile.create([".reek", ".yml"], File.dirname(path)) do |file|
  file.write(config.to_yaml)
  file.flush
  out, = Open3.capture2("reek", "--format", "json", "-c", file.path, "main.rb", "game", "tools", chdir: File.dirname(path))
  JSON.parse(out)
end
smells.group_by { |smell| smell["smell_type"] }.each do |type, list|
  # An anchored regex, so that the method set does not also exclude set_mode.
  config["detectors"][type]["exclude"] = list.map { |smell| "/\\A#{Regexp.escape(smell["context"])}\\z/" }.uniq.sort
end
File.write(path, header + config.to_yaml)
