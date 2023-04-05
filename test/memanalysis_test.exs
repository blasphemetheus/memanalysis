defmodule MemanalysisTest do
  use ExUnit.Case
  import Memanalysis
  # doctest Memanalysis

  test "read in the files" do
    {res, package} = readin(:mem_dump)
    assert res == :ok
    assert String.length(package) > 0
    assert is_binary(package)

    {res2, package2} = readin(:output, 0)
    assert res2 == :ok
    assert String.length(package2) > 0
    assert is_binary(package2)

    {res3, package3} = readin(:output, 16)
    assert res3 == :ok
    assert String.length(package3) > 0
    assert is_binary(package3)
  end

  test "    {:error, :enoent} = readin(:output, 54)
  assert res2 == :error
  assert package2 == :enoent
  assert package2 |> is_atom()" do
    assert 1 == 1

  end
end
