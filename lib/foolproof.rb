$LOAD_PATH.unshift File.dirname(__FILE__)

require 'simple_validator'
require 'parser_validator'
require 'error'

module Foolproof
  def self.validate(code)

    errors = []

    # require 'ruby-debug'; debugger
    [SimpleValidator, ParserValidator].each do |validator|
      errors.concat validator.new(code).validate_code
    end 

    errors
  end

  def self.bad_content?(content)
    return validate(content).size > 0
  end

  def self.changed_files
    has_head = system('git show HEAD')

    if has_head
      `git diff-index --cached --name-only HEAD --`.strip.split("\n")
    else
      []
    end

  end

  def self.run
    changed_files.each do |file_name|
      File.open(file_name) do |file|
        if bad_content?(file.read)
          puts "Aborting commit due to bad content in #{file.path}"
          exit(1)
        end
      end
    end
  end

end
