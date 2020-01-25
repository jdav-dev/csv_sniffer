defmodule CsvSnifferTest do
  @moduledoc """
  Based on Python's
  [CSV Sniffer tests](https://github.com/python/cpython/blob/9bfb4a7061a3bc4fc5632bccfdf9ed61f62679f7/Lib/test/test_csv.py#L933-L1052).
  """

  use ExUnit.Case, async: true

  doctest CsvSniffer
end
