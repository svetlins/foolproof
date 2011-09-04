require 'ripper'

class FoolproofParser < Ripper::SexpBuilder
  def initialize
    @invalid = nil
  end

  def keyword_values(sexp)
    sexp.map do |sub_exp|
      if keyword_value?(sub_exp)
        keyword_value(sub_exp)
      else
        keyword_values(sub_exp)
      end
    end.flatten
  end
  def on_if(cond, then_clause, else_clause)
    if keyword_values(cond).any?
      @invalid = true
    end
  end
end

def bad_content?(content)
  ['debugger', 'if true'].each do |forbidden_string|
    return true if content.include? forbidden_string
  end

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
