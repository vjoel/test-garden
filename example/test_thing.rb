require 'test-garden'

class Thing
  def cleanup; end
  def ok?; true; end
  attr_accessor :foo
end

test Thing do
  thing = Thing.new; teardown {thing.cleanup()}
  assert {thing.ok?}

  test "assign foo" do
    thing.foo = "baz" # does not affect foo in subsequent tests
    assert {thing.foo == "baz"}
  end

  test "compare foo in two instances" do
    thing2 = Thing.new; teardown {thing2.cleanup()}
    assert {thing.foo == thing2.foo}
  end
end
