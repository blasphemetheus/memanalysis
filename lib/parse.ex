defmodule Parse do
  @moduledoc """
  This module parses a binary log file for specific key words, and constructs a nested
  list structure as output. It uses recursion and accumulators
  (prepending to lists and then reversing the list later is less expensive than appending to the end of a list)
  It uses enumerables rather than streams, but a goal is to implement this with streams
  """

  @doc """
  The wrapper function that takes a binary, passes it to recursive helpers, and returns
  a nested list of the contents in a reasonable format
  That format is:
  [
    num_frames: Integer,
    KeyValue,
    KeyValue,
    KeyValue
    ...
    KeyValue
  ]

  where KeyValue is:

    key: String,
    value: [
      Item,
      Item,
      Item,
      ...
      Item
    ]
  ]

  where Item is:
  item: [
    {:range, {hexNumber, hexNumber}},
    size: hexNumber,
    reffed: [
      FrameNumber,
      FrameNumber,
      FrameNumber,
      ...
      FrameNumber
    ]
  ]

  where FrameNumber is an Integer
  where hexNumber is a tuple: { HexString, Integer }
        so for example        { "0xe0",    224     }
  """
  def parse(bin) do
    p(bin, [])
  end

  def p("", acc), do: Enum.reverse(acc)
  def p("\r\n", acc), do: Enum.reverse(acc)
  def p("\r\nKEY: " <> rest, acc), do: p("KEY: " <> rest, acc)

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

  def p("VALUE: [" <> rest, acc) do
    {v, new_rest} = parse(:value, rest, [])
    value = v |> tupelize(:value)
    new_acc = [value | acc]
    p(new_rest, new_acc)
  end

  def parse(:num_frames, "\n" <> rest, acc), do: {Enum.reverse(acc), rest}
  def parse(:key, "\r\n" <> rest, acc), do: {Enum.reverse(acc), rest}
  def parse(:value, "]" <> rest, acc), do: {Enum.reverse(acc), rest}
  def parse(:range, ", " <> rest, acc), do: {Enum.reverse(acc), rest}
  def parse(:size, ", " <> rest, acc), do: {Enum.reverse(acc), rest}
  def parse(:item, ")\r\n, " <> rest, acc), do: {Enum.reverse(acc), rest}
  def parse(:item, ")\r\n" <> rest, acc), do: {Enum.reverse(acc), rest}

  def parse(:reffed, "]" <> rest, acc) do
    {Enum.reverse(["]" |acc]), rest}
  end

  def parse(:value, "(" <> rest, acc) do
    {i, new_rest} = parse(:item, rest, [])
    item = i |> tupelize(:item)
    new_acc = [item | acc]
    parse(:value, new_rest, new_acc)
  end

  def parse(:item, "RANGE: " <> rest, acc) do
    {r, new_rest} = parse(:range, rest, [])
    range = r
    |> List.to_string()
    |> String.trim()
    |> String.split("-")
    |> Enum.map(fn x -> String.trim(x) end)
    |> Enum.map(fn raw ->
      decimal = raw |> parse_hex_str_to_int()
      {raw, decimal}
    end)
    |> List.to_tuple
    |> tupelize(:range)
    new_acc = [range | acc]
    parse(:item, new_rest, new_acc)
  end

  def parse(:item, "SIZE: " <> rest, acc) do
    {s, new_rest} = parse(:size, rest, [])
    size_hex_str = s |> List.to_string() |> String.trim()
    size_dec = size_hex_str |> parse_hex_str_to_int()
    size = {size_hex_str, size_dec} |> tupelize(:size)
    new_acc = [size | acc]

    parse(:item, new_rest, new_acc)
  end

  def parse(:item, "FRAMES REFERENCED: " <> rest, acc) do
    {r, new_rest} = parse(:reffed, rest, [])
    reffed = r |> List.to_string() |> str_to_list() |> tupelize(:reffed)
    new_acc = [reffed | acc]
    parse(:item, new_rest, new_acc)
  end

  def parse(:reffed, <<b>> <> rest, acc), do: parse(:reffed, rest, [<<b>> | acc])
  def parse(:size, <<b>> <> rest, acc), do: parse(:size, rest, [<<b>> | acc])
  def parse(:num_frames, <<b>> <> rest, acc), do: parse(:num_frames, rest, [<<b>> | acc])
  def parse(:key, <<b>> <> rest, acc), do: parse(:key, rest, [<<b>> | acc])
  def parse(:range, <<b>> <> rest, acc), do: parse(:range, rest, [<<b>> | acc])

  def parse(_atom, "", acc), do: {Enum.reverse(acc), ""}

  @doc """
  entomb that any into a tupel of {atom, any}

  iex> "freedom" |> tupelize(:joe)
  {:joe, "freedom"}
  """
  def tupelize(any, atom), do: {atom, any}

  def normalize(list, atom) do
    list |> List.to_string() |> String.trim() |> tupelize(atom)
  end

  @doc """
  Change a string which contains within it a list representation back to a list of numbers
  This is for input of the format:
  "[13316, 13317, 13318, 13319, 13320, 13321, 13322, 13323, 13324, 13325]"
  to make it
  [13316, 13317, 13318, 13319, 13320, 13321, 13322, 13323, 13324, 13325]
  """
  def str_to_list("[" <> str) do
    str |> String.replace_suffix("]", "") |> String.split(", ") |> Enum.map(fn str -> String.to_integer(str) end)
  end

  @doc """
  given a string representation of a hex number, returns the hex number as a decimal int

  iex> hex_str_to_int("0x805ca1c0")
  2153554368
  """
  def hex_str_to_int("0x" <> str) when is_binary(str) do
    str
    |> String.to_integer(16)
  end

  @doc """
  an alternate implementation of, given a string representation of a hex number,
  returns the hex number as a decimal int

  iex> hex_str_to_int("0x805ca1c0")
  2153554368
  """
  def parse_hex_str_to_int("0x" <> str) when is_binary(str) do
    case Integer.parse(str, 16) do
      {decimal, ""} -> decimal
      :error -> :parse_hex_error
      any -> {:parse_hex_error, any}
    end
  end


  @doc """
  given a number (decimal int, returns it as a string, the hex representation)
  """
  def int_to_hex_str(num) when is_integer(num) do
    hex_str = num |> Integer.to_string(16)
    "0x" <> hex_str |> String.downcase()
  end
end
