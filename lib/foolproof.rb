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
