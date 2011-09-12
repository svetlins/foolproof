class SimpleValidator

  def initialize(code)
    @code = code
  end

  def validate_code
    errors = []

    ['debugger'].each do |forbidden_string|
      @code.lines.each_with_index do |code_line, index|
        if code_line.include? forbidden_string
          errors << Error.new(:debugger_call, index + 1)
        end
      end
    end

    errors
  end
end

