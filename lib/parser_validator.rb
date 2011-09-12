require 'ripper'

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

class ParserValidator < Ripper::SexpBuilder
  attr_reader :errors

  def initialize(code)
    super(code)

    @errors = []
  end


  def on_if(cond, then_clause, else_clause)
    if_condition = SExpWrapper.new(Array(cond))

    kw_values = if_condition.keyword_values

    if kw_values.any?
      @errors << Error.new(:hardcoded_boolean, kw_values.first.line_number)
    end
  end

  def on_parse_error(*args)
    @errors << Error.new(:parse_error)
  end

  def validate_code
    parse
    return @errors
  end
end
