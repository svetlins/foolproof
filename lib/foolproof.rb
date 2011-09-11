begin
  require 'ripper'
rescue
  puts "
[FOOLPROOF] Warning: Committing code that's not validated - check your installation.
"
end

class KwValue
  def initialize(sexp)
    @sexp = sexp
  end

  def value
    string_value = @sexp.last[1]

    case string_value
    when 'true'
      true
    when 'false'
      false
    when 'nil'
      nil
    end
  end

  def line_number
    @sexp.last[2].first
  end
end

class FoolproofParser < Ripper::SexpBuilder
  attr_reader :errors

  def initialize(code)
    super(code)

    @invalid = nil
    @errors = []
  end

  def line_number(sexp)
    sexp.last.first
  end

  def keyword_value?(sexp)
    conds = [
      proc { sexp.is_a? Array },
      proc { sexp.size == 2 },
      proc { sexp.first == :var_ref },
      proc { sexp.last.first == :@kw },
      proc { ['true', 'false', 'nil'].include? sexp.last[1] }
    ]

    return conds.all? { |cond| cond.call }
  end

  def keyword_value(sexp)
    sexp.last[1]
  end

  def keyword_values(sexp)
    if sexp.is_a? Array
      sexp.map do |sub_exp|
        if keyword_value?(sub_exp)
          KwValue.new(sub_exp)
        else
          keyword_values(sub_exp)
        end
      end.flatten
    else
      []
    end
  end

  def on_if(cond, then_clause, else_clause)
    kw_values = keyword_values([cond])

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
