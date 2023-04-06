defmodule Smahty do
  def smart_parse(bin) do
    # Take first lane which are the frames
    # Divide string in Keys
    data = Regex.split(~r{\r\nKEY: }, bin, include_captures: true)
    frames = Enum.take(data, 1)
    IO.puts(frames)

    res =
      data
      |> Enum.drop(1)
      |> Enum.chunk_every(2)
      |> Enum.map(fn [x, y] -> (x <> y) |> spawn_parse()  end)
      |> Enum.map(fn _ -> recieve_parse() end)

    res
  end

  defp spawn_parse(data) do
    caller = self()
    spawn(fn -> send(caller, {:result, Parse.parse(data)}) end)
  end

  defp recieve_parse() do
    receive do
      {:result, data} -> data
    end
  end
end
