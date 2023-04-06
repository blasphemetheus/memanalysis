defmodule Watchlist do
  @doc """
  {
    "watchList": [
          {
              "groupEntries": [
                  {
                      "address": "805B6200",
                      "baseIndex": 1,
                      "label": "1",
                      "length": 48,
                      "typeIndex": 6,
                      "unsigned": false
                  },
                  {
                      "address": "805B62A0",
                      "baseIndex": 0,
                      "label": "2",
                      "length": 48,
                      "typeIndex": 6,
                      "unsigned": false
                  }
              ],
              "groupName": "System"
          }
      ]
  }

  a watchlist is pretty much a json file, but it has the format
  {
    "watchList": list_of_group_tuples
  }

  where list_of_group_tuples is:
  [
    group_tuple,
    group_tuple,
    ...
    group_tuple
  ]

  where a group_tuple is:
  {
    "groupEntries": list_of_group_entries,
    "groupName": groupName
  }

  where GroupName is: a string, so "Example Name",
    we get it from the key: field of our parsed data

  where list_of_group_entries is:
  [
    group_entry
  ]

  where group_entry is a tuple:
  {
    "address" : Address,    (variable, a Hexadecimal number as a string, no 0x prepended)
    "baseIndex" : Integer,  (variable, increments for every groupEntry, starting at 0 at the bottom)
    "label" : String,       (variable, whatever I want, lets say percentage of Num_frames)
    "length" : Integer,     (variable, resolves to `range.end - range.start`)
    "typeIndex" : 6,        (constant, the types available are always indicated by typeIndex 6)
    "unsigned" : false      (constant, the data captured is always signed)
  }

  unsigned : false
  data it's capturing is signed

  typeIndex : 6
  an index on the array of types available

  baseIndex : Integer
  the index under the group, incrementing for every groupEntry

  length : Integer
  range.end - range.start
  (range.start + length = range.end)

  where Address is: a string representing a hexadecimal number, i.e. "805B62A0"
  where Integer is: a number not in quotes, i.e. 34
  where Boolean is: either true or false (not in quotes)
  """

  def chunk(parsed) do
    # split the header with the num_frames into it's own list
    {num_frames_list, key_value_list} = parsed |> Enum.split(1)

    # grab the number of frames from the num_frames header tuple
    {:num_frames, num_frames_decimal} = num_frames_list |> List.first()

    # now we make the key value list chunked, not just one big list
    chunked_kv_list = key_value_list
    |> Enum.chunk_every(2)
    |> Enum.map(fn x -> x |> List.to_tuple() end)

    {num_frames_decimal, chunked_kv_list}
  end

  def convert_key_value_list_to_watchlist(kv_list, num_frames) do
    kv_list
    |> Enum.map(fn
      { {:key, key} = _key_tuple, {:value, list_of_items} = _value_tuple} ->
        change_item_to_groupEntries = fn
          {:item, [
            {:range, {{start_h_str, start_dec}, {end_h_str, end_dec}}},
            {:size, {size_h_str, size_dec} = _size_tuple},
            {:reffed, list_of_frames}
          ]} ->

            calc_size_dec = end_dec - start_dec
            cond do
              size_dec == calc_size_dec -> "ccol"
              true -> raise ArgumentError, message: "calculated size and size are not the same"

            end
            frames_referenced = length(list_of_frames)

            {
              {"address", start_h_str |> remove0x()},
              {"baseIndex", -1},
              {"label", "#{key} 0x#{start_h_str} - 0x#{end_h_str} with SIZE: #{
                size_h_str},#{size_dec} and frames_referenced: #{frames_referenced}/#{num_frames}"},
              {"length", size_dec},
              {"typeIndex", 6},
              {"unsigned", false}
            }
        end

        group_entries_list = list_of_items
        |> Enum.map(change_item_to_groupEntries)

        {{"groupEntries", group_entries_list}, {"groupName", key}}
    end)
  end

  @doc """
  def make_tuples_nested_tuples(kv_list) when is_list(kv_list) do
    kv_list
    |> Enum.map(fn
      {{"groupEntries", group_entries_list}, group_name_tuple} ->



  end
  """
  def make_tuples_nested_tuples({"watchList", w_kv}) do
    {{"watchList", w_kv}}
  end

  def filter_key_vals_for_some_percent_of_frames(kv_list, num_frames, percent) when percent >= 0 and percent <= 1 do
    kv_list
    |> Enum.map(fn {key_tuple, {:value, list_of_items}} ->

      item_is_reffed_in_some_percent_of_frames = fn
        {:item, [
          {:range, {{_start_h_str, _start_dec} = _start_tuple, {_end_h_str, _end_dec} = _end_tuple}},
          {:size, {_size_h_str, _size_dec} = _size_tuple},
          {:reffed, list_of_frames}
          ]} ->
            num_frames * percent <= length(list_of_frames)
      end

      filtered = list_of_items
      |> Enum.filter(item_is_reffed_in_some_percent_of_frames)

      {key_tuple, {:value, filtered}}
    end)
    |> Enum.reject(fn {_key_tuple, {:value, list}} -> length(list) == 0 end)
  end

  @doc """
  Given a group entry list, inserts the correct baseIndexes
  into all the group entries
  """
  def give_baseIndex(group_entry_list) do
    end_index = length(group_entry_list) - 1
    indexes = for ind <- end_index..0, do: ind

    Enum.map(Stream.zip(indexes, group_entry_list),
    fn {index, {addr_tup, {"baseIndex", -1}, label_tup, length_tup, type_tup, unsign_tup}} ->
      {addr_tup, {"baseIndex", index}, label_tup, length_tup, type_tup, unsign_tup}
    end)
  end

  def fill_in_baseIndex(kv_list) do
    kv_list
    |> Enum.map(fn
      {{"groupEntries", group_entries_list}, group_name_tuple} ->
        new_group_entries = group_entries_list |> give_baseIndex()

        {{"groupEntries", new_group_entries}, group_name_tuple}
    end)
  end

  def remove0x("0x" <> str), do: str
end
