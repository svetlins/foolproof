def bad_content?(content)
  ['debugger', 'if true'].each do |forbidden_string|
    return true if content.include? forbidden_string
  end

  return false
end
