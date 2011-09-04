require 'test/unit'
require 'lib/foolproof.rb'

# Unit Test
class FoolproofTest < Test::Unit::TestCase
  TEST_FILES_DIR = 'test_files/'

  def on_file(file_name)
    File.open(File.join(File.dirname(__FILE__), TEST_FILES_DIR, file_name)) do |file|
      yield file.read
    end
  end

  def assert_file_rejected(file_name)
    assert on_file(file_name) { |content| bad_content?(content) }
  end

  def assert_file_accept
    assert on_file(file_name) { |content| !bad_content?(content) }
  end

  def setup
  end

  def test_basic
    assert_file_rejected 'forgotten_debugger.rb'
  end
end

# Integration test
class FoolproofTestIntegration < Test::Unit::TestCase
  def setup
  end

  def test_basic
  end
end
