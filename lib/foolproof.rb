require 'ripper'

class FoolproofParser < Ripper::SexpBuilder
  def initialize(code)
    super(code)

    @invalid = nil
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
          keyword_value(sub_exp)
        else
          keyword_values(sub_exp)
        end
      end.flatten
    else
      []
    end
  end

  def on_if(cond, then_clause, else_clause)
    if keyword_values([cond]).any?
      @invalid = true
    end
  end

  def invalid?
    @invalid
  end
end

def bad_content?(content)
  ['debugger'].each do |forbidden_string|
    return true if content.include? forbidden_string
  end

  parser = FoolproofParser.new(content)
  parser.parse
  return true if parser.invalid?

  return false
end

def changed_files
  has_head = system('git show HEAD')

  if has_head
    `git diff-index --cached --name-only HEAD --`.strip.split("\n")
  else
    []
  end

end
