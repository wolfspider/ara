defmodule ARATest do
  use ExUnit.Case
  doctest ARA

  test "greets the world" do
    assert ARA.hello() == :world
  end

  test "mime lookup" do
    mime_map = Mime.of_file("mime.types")
    mime_result = Mime.lookup(mime_map, ".html")
    IO.puts("Mime Result: #{mime_result}")
    assert mime_result == "text/html"
  end
end
