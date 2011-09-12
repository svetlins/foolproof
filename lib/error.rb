class Error
  attr_reader :kind, :line_number

  def initialize(kind, line_number = nil)
    @kind = kind
    @line_number = line_number
  end

  def ==(other)
    other.kind == kind && other.line_number == line_number
  end
end
