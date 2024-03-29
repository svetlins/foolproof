require 'test/unit'
require 'lib/foolproof.rb'
require 'fileutils'




module TestFiles
  BASE_DIR = Dir.pwd # Is this bad ?
  TEST_FILES_DIR = 'test_files/'

  private 

  def test_file_path(file_name)
    File.join(BASE_DIR, TEST_FILES_DIR, file_name)
  end
end

# Unit Test
class FoolproofTest < Test::Unit::TestCase
  include TestFiles

  def validate(*args)
    Foolproof.validate(*args)
  end

  def assert_on_content_or_file(file_content_or_name, expected, message)
    content = nil

    if File.exists?(test_file_path file_content_or_name)
      File.open(test_file_path file_content_or_name) do |file|
        content = file.read
      end
    else
      content = file_content_or_name
    end

    unless content.nil?
      errors = validate content

      assert_equal expected, yield(errors), "#{file_content_or_name} #{message}. Errors: #{errors.inspect} "
    else
      raise "No content given"
    end
  end

  def assert_file_rejected(file_content_or_name)
    assert_on_content_or_file(
      file_content_or_name,
      true,
      'wrongly accepted'
    ) { |errors| errors.size > 0 }
  end

  def assert_file_accepted(file_content_or_name)
    assert_on_content_or_file(
      file_content_or_name,
      true,
      'wrongly rejected'
    ) { |errors| errors.size == 0 }
  end

  def assert_reports_error(file_content_or_name, error_kind, line_number)

    assert_on_content_or_file(
      file_content_or_name,
      Error.new(error_kind, line_number),
      'didn\'t correctly report errors'
    ) { |errors| errors.first }
  end

  def setup
  end

  def test_basic
    assert_file_rejected 'forgotten_debugger.rb'
    assert_file_accepted 'good_file.rb'
  end

  def test_basic_error_report
    assert_reports_error 'forgotten_debugger.rb', :debugger_call, 2
    assert_reports_error 'hardcoded_if.rb', :hardcoded_boolean, 1
  end

  def test_hardcoded_if
    assert_file_rejected "
      if true
       puts 'it\\'s true!'
      end
    "
  end

  def test_complex_hardcoded_if
    assert_file_rejected "
      if var_name || true
       puts 'is it?'
      end
    "
  end

  def test_invalid_code
    assert_file_rejected "
      iftrup this code should not pass
        puts 'test123'
      end
    "

    assert_file_rejected "
      'it's a good life' # Unescaped quote
    "

    assert_file_accepted "
      'it\\'s a good life'
    "

    assert_file_rejected "
      if ((42 && 69 || zero) # Unbalanced parens
        puts 'foobar'
      end
    "
    assert_file_accepted "
      if ((42 && 69 || zero))
        puts 'foobar'
      end
    "
  end

  def test_parser_keyword_values
    # [if true]
    sexp = [:var_ref, [:@kw, "true", [3, 4]]]
    assert_equal [true], SExpWrapper.new(sexp).keyword_values.map(&:value)
    # SExp.new([:var_ref, [:@kw, "true", [3, 4]]]).keyword_values

    # if (foobar(42) && get_name || false || 42 && nil || (bla && get_foo(true)))
    sexp = [:paren, [:stmts_add, [:stmts_new], [:binary, [:binary, [:binary, [:binary, [:method_add_arg, [:fcall, [:@ident, "foobar", [3, 5]]], [:arg_paren, [:args_add_block, [:args_add, [:args_new], [:@int, "42", [3, 12]]], false]]], :"&&", [:var_ref, [:@ident, "get_name", [3, 19]]]], :"||", [:var_ref, [:@kw, "false", [3, 31]]]], :"||", [:binary, [:@int, "42", [3, 40]], :"&&", [:var_ref, [:@kw, "nil", [3, 46]]]]], :"||", [:paren, [:stmts_add, [:stmts_new], [:binary, [:var_ref, [:@ident, "bla", [3, 54]]], :"&&", [:method_add_arg, [:fcall, [:@ident, "get_foo", [3, 61]]], [:arg_paren, [:args_add_block, [:args_add, [:args_new], [:var_ref, [:@kw, "true", [3, 69]]]], false]]]]]]]]]
    assert_equal [false, nil, true], SExpWrapper.new(sexp).keyword_values.map(&:value)

  end
end

# Integration test
class FoolproofTestIntegration < Test::Unit::TestCase
  include TestFiles

  TEST_GIT_DIR_NAME = 'test_git'

  # Delegate to git
  ['init', 'commit', 'add'].each do |git_command|
    define_method "git_#{git_command}" do |*args|
      `git #{git_command} #{args.join(' ')} > /dev/null 2> /dev/null`
    end
  end

  def add_file(file_path, content = nil)
    file_dir_structure = File.split(file_path)[0...-1]
    file_name = File.split(file_path)[-1]

    if content.nil?
      File.open(test_file_path(file_name)) do |file|
        content = file.read
      end
    end

    FileUtils.makedirs(file_dir_structure)

    File.open(file_path, 'w') do |file|
      file.write(content)
    end

    git_add(file_path)
  end

  def install_pre_commit_hook
    # Dir.mkdir(File.join('.git', 'hooks', 'lib'))

    # FileUtils.cp(File.join(BASE_DIR, 'lib', 'foolproof.rb'), File.join('.git', 'hooks', 'lib', 'foolproof.rb'))

    # Need to set up the load path - when installed as gem this won't be needed
    ENV['RUBYLIB'] = File.join(BASE_DIR, 'lib')

    File.open(File.join('.git', 'hooks', 'pre-commit'), 'w') do |install_to|
      File.open(File.join(BASE_DIR, 'lib', 'pre-commit.rb')) do |install_from|
        install_to.write(
          install_from.read
        )

        install_to.chmod(0744) # Make executable
      end
    end
  end

  def assert_git_fail
    assert_not_equal $?.exitstatus, 0, 'git didn\'t fail'
  end

  def assert_git_success
    assert_equal $?.exitstatus, 0, 'git didn\'t succeed'
  end

  def setup
    Dir.mkdir(TEST_GIT_DIR_NAME)
    Dir.chdir(TEST_GIT_DIR_NAME)

    git_init
    install_pre_commit_hook
    add_file(
      'README',
      "This is a test git repository.
       If you see it that means something went wrong.
       It's safe to delete it"
    )
    git_commit('-m "initial commit"') # We have a HEAD now :)
  end

  def teardown
    Dir.chdir(BASE_DIR)
    `rm -rf #{TEST_GIT_DIR_NAME}`
  end

  def test_basic_reject
    add_file('forgotten_debugger.rb')
    git_commit('-m "adding file with a forgotten debugger"')

    assert_git_fail
  end

  def test_basic_accept
    add_file('good_file.rb')
    git_commit('-m "adding a good file that shouldn\'t stop commit"')

    assert_git_success
  end

  def test_nested_reject
    add_file(File.join('lib', 'nested', 'file', 'forgotten_debugger.rb'))
    git_commit('-m "adding a nested file with a forgotten debugger"')

    assert_git_fail
  end

  def test_nested_accept
    add_file(File.join('lib', 'nested', 'file', 'good_file.rb'))
    git_commit('-m "adding a good nested file"')

    assert_git_success
  end

  def test_hardcoded_if_true
    add_file(File.join('hardcoded_if.rb'))
    git_commit('-m "adding a file with a hardcoded if true"')

    assert_git_fail
  end

  # def test_complex_hardcoded_if
  #   add_file(File.join('complex_hardcoded_if.rb'))
  #   git_commit('-m "adding a file with a complex hardcoded if"')

  #   assert_git_fail
  # end
end
