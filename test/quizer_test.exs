defmodule QuizerTest do
  use ExUnit.Case
  doctest Quizer

  test "greets the world" do
    assert Quizer.hello() == :world
  end
end
