#!/usr/bin/env ruby

$LOAD_PATH.unshift(
  File.join(Dir.pwd, '.git', 'hooks')
)

require 'lib/foolproof'

changed_files.each do |file_name|
  File.open(file_name) do |file|
    if bad_content?(file.read)
      puts "Aborting commit due to bad content in #{file.path}"
      exit(1)
    end
  end
end
