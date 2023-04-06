defmodule Memanalysis do
  @moduledoc """
  Documentation for `Memanalysis`.
  """

  # looking for addresses of memory relevant to game state
  # stage objects (items, fighters, stage itself, articles, projectiles etc)
  # that can impact game state

  # Stuff present in frames from around start of match
  # until around the end of the match,
  # then rev eng what allocation translates to in-game

  # To make output files, run fn called DumpAll,
  # prints every allocation in the game to OSReport,
  # every frame of the replay.
  # Redirects output to a file on dolphin side
  # A python script then produces the output files
  # Just rearranging the information


  # GOOD READING: https://hansonkd.medium.com/building-beautiful-binary-parsers-in-elixir-1bd7f865bf17

  @keys ["NUM FRAMES: ", "\n", "KEY: ", "VALUE: ", "[", "(", "RANGE: ", "SIZE: ", "FRAMES REFERENCED: ", "]", ")", ]

  def main() do
    main(:sync, :test)
    for i <- 0..16, do: main(:sync, i)
    IO.puts("COMPLETELY FINISHED")
    for _i <- 0..5, do: IO.puts("____________________________________")
  end
  def main(:stream!) do
    # this doesn't really work atm, still figuring out what's actually different about Streams
    # I know Stream.map() is basically Enum.map() but evaluated lazily, but
    # making the parse stuff gel with Streams is the next task
    stream = intake(:output, 0, :stream!)

    hits_keyword = &(&1 in @keys)
    Stream.chunk_by(stream, hits_keyword)
    |> Stream.take(1)
  end

  def main(:async) do
    {:ok, bin} = Memanalysis.intake(:output, 0)
    Smahty.smart_parse(bin)
  end

  def main(:sync, num \\ :test) do
    {:ok, start} = DateTime.now("Etc/UTC")
    IO.puts("Start file #{num}__ minute: #{start.minute}, second: #{start.second}")
    n = num
    # using number three as my example here,
    # go ahead and try this in iex if you want (with different output files)
    # (`iex -S mix` to start it up, `iex.bat -S mix` in Powershell)
    {:ok, bin} = Memanalysis.intake(:output, n, :read)
    parsed = Parse.parse(bin)

    {num_frames, kv_list_chunked} = Watchlist.chunk(parsed)

    key_value_list = kv_list_chunked
    |> Watchlist.filter_key_vals_for_some_percent_of_frames(num_frames, 0.7)

    watchlist_kv = Watchlist.convert_key_value_list_to_watchlist(key_value_list, num_frames)
    |> Watchlist.fill_in_baseIndex()

    output = {"watchList", watchlist_kv}
    |> stringify()

    output
    |> sendToFile("dump_watchlist#{n}.dmw")

    case n do
      :test -> IO.puts(output)
      _ -> IO.puts("done")
    end

    {:ok, finish} = DateTime.now("Etc/UTC")
    IO.puts("Start __ minute: #{start.minute}, second: #{start.second}")
    IO.puts("End __ minute: #{finish.minute}, second: #{finish.second}")

    #{num_frames_list, key_value_list} = parsed |> Enum.ssplit(1)
    #{:num_frames, num_frames_decimal} = num_frames_list |> List.first()
    #IO.puts("The number of frames is : #{num_frames_decimal}")
    # so now we process the key value list
    #key_value_list |> Enum.chunk_every(2)
    #|> Enum.map(fn list_of_key_then_value ->
    #  list_of_key_then_value
    #end)
  end

  def stringify(cool) do
    cool
    |> Watchlist.make_tuples_nested_tuples()
    |> inspect(limit: :infinity)
    |> String.replace("\",", "\":")
    |> bracket_replace()
  end

  def bracket_replace("{{" <> rest) do
    "{" <> bracket_replace(rest)
  end
  def bracket_replace("}}" <> rest) do
    "}" <> bracket_replace(rest)
  end
  def bracket_replace("{" <> rest) do
    bracket_replace(rest)
  end
  def bracket_replace("}" <> rest) do
    bracket_replace(rest)
  end
  def bracket_replace("") do
    ""
  end
  def bracket_replace(<<t>> <> rest) do
    <<t>> <> bracket_replace(rest)
  end

  @doc """
  intakes a csv or output txt file (logs in different formats)
  either as a Stream (which raises exceptions on error), (with style :stream!)
  or as a binary held in memory (with style :read)

  ## Examples

      iex> Memanalysis.intake(:output, 54, :read)
      {:error, :enoent}
  """
  def intake(atom, n \\ :test, style \\ :read)
  def intake(:csv, _n, :read), do: {:ok, _f} = File.read("mem_dump.csv")
  def intake(:csv, _n, :stream!), do: File.stream!("mem_dump.csv")
  def intake(:output, :test, :read), do: {:ok, _f} = File.read("ProjectPlusMemory/outputtest.txt")
  def intake(:output, :test, :stream!), do: File.stream!("ProjectPlusMemory/outputtest.txt")

  def intake(:output, n, :read) when n > -1 and n < 17 do
    {:ok, _f} = File.read("ProjectPlusMemory/output#{n}.txt")
  end

  def intake(:output, n, :stream!) when n > -1 and n < 17 do
    File.stream!("ProjectPlusMemory/output#{n}.txt")
  end

  def intake(:output, n, _style) do
    raise ArgumentError, message: "Please specify an output file between 0 and 16 inclusive: got #{inspect(n)}"
  end

  @doc """
  sends binary data to a file
  """
  def sendToFile(binary, path) do
    File.write(path, binary)
    #{:ok, f} = case File.exists?(path) do
    ##  true -> File.open(path)
    #  false ->
    #    File.touch(path)
    #    File.open(path)
    #end
    #IO.write(f, binary)
    #File.write(path, binary) # for when not writing in a loop
  end
end
