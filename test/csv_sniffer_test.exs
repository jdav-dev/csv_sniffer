defmodule CsvSnifferTest do
  @moduledoc """
  Based on Python's
  [CSV Sniffer tests](https://github.com/python/cpython/blob/9bfb4a7061a3bc4fc5632bccfdf9ed61f62679f7/Lib/test/test_csv.py#L933-L1052).
  """

  use ExUnit.Case, async: true

  alias CsvSniffer.Dialect

  doctest CsvSniffer

  @sample1 """
  Harry's, Arlington Heights, IL, 2/1/03, Kimi Hayes
  Shark City, Glendale Heights, IL, 12/28/02, Prezence
  Tommy's Place, Blue Island, IL, 12/28/02, Blue Sunday/White Crow
  Stonecutters Seafood and Chop House, Lemont, IL, 12/19/02, Week Back
  """
  @sample2 """
  'Harry''s';'Arlington Heights';'IL';'2/1/03';'Kimi Hayes'
  'Shark City';'Glendale Heights';'IL';'12/28/02';'Prezence'
  'Tommy''s Place';'Blue Island';'IL';'12/28/02';'Blue Sunday/White Crow'
  'Stonecutters ''Seafood'' and Chop House';'Lemont';'IL';'12/19/02';'Week Back'
  """
  @sample3 """
  05/05/03;05/05/03;05/05/03;05/05/03;05/05/03
  05/05/03;05/05/03;05/05/03;05/05/03;05/05/03;05/05/03
  05/05/03;05/05/03;05/05/03;05/05/03;05/05/03;05/05/03
  """
  @sample4 """
  2147483648;43.0e12;17;abc;def
  147483648;43.0e2;17;abc;def
  47483648;43.0;170;abc;def
  """
  @sample5 "aaa\tbbb\r\nAAA\t\r\nBBB\t\r\n"
  @sample6 "a|b|c\r\nd|e|f\r\n"
  @sample7 "'a'|'b'|'c'\r\n'd'|e|f\r\n"
  @sample8 """
  Harry's| Arlington Heights| IL| 2/1/03| Kimi Hayes
  Shark City| Glendale Heights| IL| 12/28/02| Prezence
  Tommy's Place| Blue Island| IL| 12/28/02| Blue Sunday/White Crow
  Stonecutters Seafood and Chop House| Lemont| IL| 12/19/02| Week Back
  """
  @sample9 """
  'Harry''s', Arlington Heights', 'IL', '2/1/03', 'Kimi Hayes'
  'Shark City', Glendale Heights', 'IL', '12/28/02', 'Prezence'
  'Tommy''s Place', Blue Island', 'IL', '12/28/02', 'Blue Sunday/White Crow'
  'Stonecutters ''Seafood'' and Chop House', 'Lemont', 'IL', '12/19/02', 'Week Back'
  """
  @sample10 """
  'Harry''s':'Arlington Heights':'IL':'2/1/03':'Kimi Hayes'
  'Shark City':'Glendale Heights':'IL':'12/28/02':'Prezence'
  'Tommy''s Place':'Blue Island':'IL':'12/28/02':'Blue Sunday/White Crow'
  'Stonecutters ''Seafood'' and Chop House':'Lemont':'IL':'12/19/02':'Week Back'
  """
  @header1 """
  "venue","city","state","date","performers"
  """
  @header2 """
  "venue"+"city"+"state"+"date"+"performers"
  """

  # describe "has_header?/1" do
  #   test "returns false for a sample without headers" do
  #     refute CsvSniffer.has_header?(@sample1)
  #   end

  #   test "returns true for a sample with headers" do
  #     assert CsvSniffer.has_header?(@header1 <> @sample1)
  #   end

  #   test "returns false for a sample without headers and a special delimiter" do
  #     refute CsvSniffer.has_header?(@sample8)
  #   end

  #   test "returns true for a sample with headers and a special delimiter" do
  #     assert CsvSniffer.has_header?(@header2 <> @sample8)
  #   end
  # end

  describe "sniff/2" do
    test ~s/on header ";'123;4';"/ do
      assert {:ok,
              %Dialect{
                delimiter: ";",
                quote_character: "'",
                quote_needed: true
              }} == CsvSniffer.sniff(";'123;4';")
    end

    test ~s/on header "'123;4';"/ do
      assert {:ok,
              %Dialect{
                delimiter: ";",
                quote_character: "'",
                quote_needed: true
              }} == CsvSniffer.sniff("'123;4';")
    end

    test ~s/on header ";'123;4'"/ do
      assert {:ok,
              %Dialect{
                delimiter: ";",
                quote_character: "'",
                quote_needed: true
              }} == CsvSniffer.sniff(";'123;4'")
    end

    test ~s/on header "'123;4'"/ do
      assert {:ok,
              %Dialect{
                delimiter: ";",
                quote_character: nil,
                quote_needed: false
              }} == CsvSniffer.sniff("'123;4'")
    end

    test "on sample1" do
      assert {:ok,
              %Dialect{
                delimiter: ",",
                quote_character: nil,
                quote_needed: false
              }} == CsvSniffer.sniff(@sample1)
    end

    test "on sample2" do
      assert {:ok,
              %Dialect{
                delimiter: ";",
                quote_character: "'",
                quote_needed: true
              }} == CsvSniffer.sniff(@sample2)
    end

    test "on sample3 without specifying delimiter" do
      {:error, "Could not determine delimiter"} = CsvSniffer.sniff(@sample3)
    end

    test "on sample4" do
      assert {:ok, %Dialect{delimiter: ";"}} == CsvSniffer.sniff(@sample4)
    end

    test "on sample5" do
      assert {:ok, %Dialect{delimiter: "\t"}} == CsvSniffer.sniff(@sample5)
    end

    test "on sample6" do
      assert {:ok, %Dialect{delimiter: "|"}} == CsvSniffer.sniff(@sample6)
    end

    test "on sample7" do
      assert {:ok, %Dialect{delimiter: "|", quote_character: "'", quote_needed: true}} ==
               CsvSniffer.sniff(@sample7)
    end

    test "on sample8" do
      assert {:ok, %Dialect{delimiter: "|", quote_needed: false}} ==
               CsvSniffer.sniff(@sample8)
    end

    test "on sample9" do
      assert {:ok,
              %Dialect{
                delimiter: ",",
                quote_character: "'",
                quote_needed: true
              }} ==
               CsvSniffer.sniff(@sample9)
    end

    test "on sample10" do
      assert {:error, "Could not determine delimiter"} == CsvSniffer.sniff(@sample10)
    end

    test "on header1" do
      assert {:ok, %Dialect{delimiter: ",", quote_character: "\"", quote_needed: true}} ==
               CsvSniffer.sniff(@header1)
    end

    test "on header2" do
      assert {:error, "Could not determine delimiter"} == CsvSniffer.sniff(@header2)
    end
  end
end
