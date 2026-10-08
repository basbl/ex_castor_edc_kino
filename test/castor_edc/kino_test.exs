defmodule CastorEDC.KinoTest do
  use ExUnit.Case
  doctest CastorEDC.Kino

  test "greets the world" do
    assert CastorEDC.Kino.hello() == :world
  end
end
