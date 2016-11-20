require 'test_helper'

class TrainmasterTest < ActiveSupport::TestCase
  test "truth" do
    assert_kind_of Module, Trainmaster
  end

  test "basic cache operations" do
    Trainmaster::Cache.set("foo", 42)
    assert_equal 42, Trainmaster::Cache.get("foo")
  end
end
