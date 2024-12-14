defmodule ARATest do
  use ExUnit.Case
  doctest ARA

  test "greets the world" do
    assert ARA.hello() == :world
  end
end
