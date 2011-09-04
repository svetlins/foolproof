require 'test/unit'
require 'lib/foolproof.rb'


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

  def assert_on_content_or_file(file_content_or_name, message)
    content = nil

    if File.exists?(test_file_path file_content_or_name)
      File.open(test_file_path file_content_or_name) do |file|
        content = file.read
      end
    else
      content = file_content_or_name
    end

    unless content.nil?
      assert yield(content), "#{file_content_or_name} #{message}"
    else
      raise "No content given"
    end
  end

  def assert_file_rejected(file_content_or_name)
    assert_on_content_or_file(file_content_or_name, 'wrongly accepted') { |content| bad_content?(content) }
  end

  def assert_file_accepted(file_content_or_name)
    assert_on_content_or_file(file_content_or_name, 'wrongly rejected') { |content| !bad_content?(content) }
  end

  def setup
  end

  def test_basic
    assert_file_rejected 'forgotten_debugger.rb'
    assert_file_accepted 'good_file.rb'
  end

  def test_hardcoded_if
    assert_file_rejected "
      if true
    "
  end
end

# Integration test
class FoolproofTestIntegration < Test::Unit::TestCase
  include TestFiles

  TEST_GIT_DIR_NAME = 'test_git'

  # Delegate to git
  ['init', 'commit', 'add'].each do |git_command|
    define_method "git_#{git_command}" do |*args|
      `git #{git_command} #{args.join(' ')}`
    end
  end

  def add_file(file_name, content = nil)
    if content.nil?
      File.open(test_file_path(file_name)) do |file|
        content = file.read
      end
    end

    File.open(file_name, 'w') do |file|
      file.write(content)
    end

    git_add(file_name)
  end

  def install_pre_commit_hook
    File.open('.git/hooks/pre-commit', 'w') do |file|
      file.write("#!/usr/bin/env ruby
                 exit(1)
                 ")
      file.chmod(0744) # Make executable
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
    add_file('README', 'This is a test git repository. If you see it that means something went wrong. It\'s safe to delete it')
    git_commit('-m "initial commit"') # We have a HEAD now :)
  end

  def teardown
    Dir.chdir(BASE_DIR)
    `rm -rf #{TEST_GIT_DIR_NAME}`
  end

  def test_basic
    add_file('forgotten_debugger.rb')
    git_commit('-m "adding file with a forgotten debugger"')

    assert_git_fail
  end
end