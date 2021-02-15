defmodule ExLoxTest do
  use ExUnit.Case
  doctest ExLox

  test "greets the world" do
    assert ExLox.hello() == :world
  end
end
