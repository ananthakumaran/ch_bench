defmodule ChBenchTest do
  use ExUnit.Case
  doctest ChBench

  test "greets the world" do
    assert ChBench.hello() == :world
  end
end
