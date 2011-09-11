begin
  require 'ripper'
rescue
  puts "
[FOOLPROOF] Can't load ripper parser - check your ruby instalation. Commit aborted.
"
  exit(1)
end

class SExpWrapper
  def initialize(s)
    @s = s
  end

  def line_number
    @s.last.first
  end

  def value
    case keyword_value
    when 'true'
      true
    when 'false'
      false
    when 'nil'
      nil
    end
  end

  def keyword_value?
    conds = [
      proc { @s.is_a? Array },
      proc { @s.size == 3 },
      proc { @s.first == :@kw },
      proc { ['true', 'false', 'nil'].include? @s[1] }
    ]

    return conds.all? { |cond| cond.call }
  end

  def keyword_value
    @s[1]
  end

  def keyword_values
    if @s.is_a? Array
      @s.map do |sub_exp|

        wrapped_sub_sexp = SExpWrapper.new(sub_exp)

        if wrapped_sub_sexp.keyword_value?
          wrapped_sub_sexp
        else
          wrapped_sub_sexp.keyword_values
        end
      end.flatten
    else
      []
    end
  end
end

class FoolproofParser < Ripper::SexpBuilder
  attr_reader :errors

  def initialize(code)
    super(code)

    @invalid = nil
    @errors = []
  end


  def on_if(cond, then_clause, else_clause)
    if_condition = SExpWrapper.new(Array(cond))

    kw_values = if_condition.keyword_values

    if kw_values.any?
      @invalid = true
      @errors << [:hardcoded_boolean, kw_values.first.line_number]
    end
  end

  def on_parse_error(*args)
    @invalid = true
    @errors << [:parse_error]
  end

  def invalid?
    @invalid
  end
end

module Foolproof
  def self.validate(content)
    # Simple string matching goes here
    ['debugger'].each do |forbidden_string|
      content.lines.each_with_index do |content_line, index|
        if content_line.include? forbidden_string
          return [[:debugger_call, index + 1]]
        end
      end
    end

    # More involved inspection of the syntax tree goes here
    parser = FoolproofParser.new(content)
    parser.parse

    return parser.errors
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
