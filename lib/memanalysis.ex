defmodule Memanalysis do
  @moduledoc """
  Documentation for `Memanalysis`.
  """

  # BELIEVER SAYS USE STREAM.CHUNK and I did look at it, but became confused,
  # So here's the
  #
  # INFO FROM WHITEPOISON

  # Relevant to Game state -> we're looking for addresses of memory that fits that
  # so stage objects can directly impact
  # stage objects -> items, fighters, stage itself, articles, projectiles etc

  # So, look at the output and look for stuff that's there from around the start of the match
  # until around the end of the match, and RE what that allocation actually is in the game

  # To produce these files, I started by running a function called DumpAll,
  # which prints every allocation in the game to OSReport, every frame of the replay
  # And redirected the output to a file on dolphin side
  # I then ran a script that produces the output files
  # Essentially just rearranging the information


  # GOOD READING: https://hansonkd.medium.com/building-beautiful-binary-parsers-in-elixir-1bd7f865bf17

  @keys ["NUM FRAMES: ", "\n", "KEY: ", "VALUE: ", "[", "(", "RANGE: ", "SIZE: ", "FRAMES REFERENCED: ", "]", ")", ]
  def main(:stream) do
    # this doesn't really work atm, still figuring out what's actually different about Streams
    # I know Stream.map() is basically Enum.map() but evaluated lazily, but
    # making the parse stuff gel with Streams is the next task
    stream = streamin(:output, 0)

    hits_keyword = &(&1 in @keys)
    Stream.chunk_by(stream, hits_keyword)
    |> Stream.take(1)
  end

  def main() do
    # using number three as my example here,
    # go ahead and try this in iex if you want (with different output files)
    # (`iex -S mix` to start it up, `iex.bat -S mix` in Powershell)
    {:ok, bin} = Memanalysis.readin(:output, 3)
    {num_frames_list, key_value_list} = Memanalysis.parse(bin) |> Enum.split(1)

    {:num_frames, num_frames} = num_frames_list |> List.first()

    key_value_list |> Enum.chunk_every(2)
  end

  @doc """
  Reads in the memory files as specified

  ## Examples

      iex> Memanalysis.readin(:output, 54)
      {:error, :enoent}
  """
  def readin(:mem_dump) do
    {:ok, _f} = File.read("mem_dump.csv")
  end

  def readin(:output, :test) do
    {:ok, _f} = File.read("ProjectPlusMemory/outputtest.txt")
  end

  def readin(:output, n) when n > -1 and n < 17 do
    {:ok, _f} = File.read("ProjectPlusMemory/output#{n}.txt")
  end

  def readin(:output, n) do
    raise ArgumentError, message: "Please specify an output file between 0 and 16 inclusive: got #{inspect(n)}"
  end

  def streamin(:output, n) when n > -1 and n < 17 do
    File.stream!("ProjectPlusMemory/output#{n}.txt")
  end

  def parse(bin) do
    p(bin, [])
  end


  def p("", acc) do
    Enum.reverse(acc)
  end

  def p("\r\n", acc), do: Enum.reverse(acc)

  def p("NUM FRAMES: " <> rest, acc) do

    {frames, new_rest} = parse(:num_frames, rest, [])
    f = frames |> List.to_string() |> String.trim() |> String.to_integer() |> tupelize(:num_frames)
    new_acc = [f | acc]
    p(new_rest, new_acc)
  end

  def p("KEY: " <> rest, acc) do
    {k, new_rest} = parse(:key, rest, [])
    key = k |> normalize(:key)
    new_acc = [key | acc]
    p(new_rest, new_acc)
  end

  def p("\r\nKEY: " <> rest, acc), do: p("KEY: " <> rest, acc)

  def p("VALUE: [" <> rest, acc) do
    {v, new_rest} = parse(:value, rest, [])
    value = v |> tupelize(:value)
    new_acc = [value | acc]
    p(new_rest, new_acc)
  end

  def parse(:num_frames, "\n" <> rest, acc) do
    {Enum.reverse(acc), rest}
  end

  def parse(:key, "\r\n" <> rest, acc) do
    {Enum.reverse(acc), rest}
  end

  def parse(:value, "]" <> rest, acc) do
    {Enum.reverse(acc), rest}
  end

  def parse(:range, ", " <> rest, acc) do
    {Enum.reverse(acc), rest}
  end

  def parse(:size, ", " <> rest, acc) do
    {Enum.reverse(acc), rest}
  end

  def parse(:reffed, "]" <> rest, acc) do
    {Enum.reverse(["]" |acc]), rest}
  end

  def parse(:item, ")\r\n, " <> rest, acc) do
    {Enum.reverse(acc), rest}
  end

  def parse(:item, ")\r\n" <> rest, acc) do
    {Enum.reverse(acc), rest}
  end

  def parse(:value, "(" <> rest, acc) do
    {i, new_rest} = parse(:item, rest, [])
    item = i |> tupelize(:item)
    new_acc = [item | acc]
    parse(:value, new_rest, new_acc)
  end

  def parse(:item, "RANGE: " <> rest, acc) do
    {r, new_rest} = parse(:range, rest, [])
    range = r |> normalize(:range)
    new_acc = [range | acc]
    parse(:item, new_rest, new_acc)
  end

  def parse(:item, "SIZE: " <> rest, acc) do
    {s, new_rest} = parse(:size, rest, [])
    size = s |> normalize(:size)
    new_acc = [size | acc]
    parse(:item, new_rest, new_acc)
  end

  def parse(:item, "FRAMES REFERENCED: " <> rest, acc) do
    {r, new_rest} = parse(:reffed, rest, [])
    reffed = r |> List.to_string() |> str_to_list() |> tupelize(:reffed)
    new_acc = [reffed | acc]
    parse(:item, new_rest, new_acc)
  end

  def parse(:reffed, <<thing>> <> rest, acc) do
    parse(:reffed, rest, [<<thing>> | acc])
  end

  def parse(:size, <<thing>> <> rest, acc) do
    parse(:size, rest, [<<thing>> | acc])
  end

  def parse(:num_frames, <<thing>> <> rest, acc) do
    parse(:num_frames, rest, [<<thing>> | acc])
  end

  def parse(:key, <<thing>> <> rest, acc) do
    parse(:key, rest, [<<thing>> | acc])
  end

  def parse(:range, <<thing>> <> rest, acc) do
    parse(:range, rest, [<<thing>> | acc])
  end

  def parse(_atom, "", acc) do
    {Enum.reverse(acc), ""}
  end

  def tupelize(string, atom), do: {atom, string}

  def normalize(list, atom) do
    list |> List.to_string() |> String.trim() |> tupelize(atom)
  end

  @doc """
  Change a string which contains within it a list representation back to a list of numbers
  This is for input of the format:
  "[13316, 13317, 13318, 13319, 13320, 13321, 13322, 13323, 13324, 13325]"
  to make it
  ["13316", "13317", "13318", "13319", "13320", "13321", "13322", "13323", "13324", "13325"]
  """
  def str_to_list("[" <> str) do
    str |> String.replace_suffix("]", "") |> String.split(", ") |> Enum.map(fn str -> String.to_integer(str) end)
  end

  #def parseNFrames("KEY: " <> key_name <> "\n" <> rest, acc) do
  #end
  #String.to



end
