defmodule CsvSniffer do
  @moduledoc """
  An Elixir port of Python's
  [CSV Sniffer](https://github.com/python/cpython/blob/9bfb4a7061a3bc4fc5632bccfdf9ed61f62679f7/Lib/csv.py#L165-L448).
  """
  @moduledoc since: "0.1.0"

  alias CsvSniffer.Dialect

  @preferred [",", "\t", ";", " ", ":"]

  @doc """
  "Sniffs" the format of a CSV sample (i.e. delimiter, quote character).

  ## Options

    * `:delimiters` - Limit the sniffer to a list of possible delimiters.

  ## Examples

      iex> \"""
      ...> Harry's, Arlington Heights, IL, 2/1/03, Kimi Hayes
      ...> Shark City, Glendale Heights, IL, 12/28/02, Prezence
      ...> Tommy's Place, Blue Island, IL, 12/28/02, Blue Sunday/White Crow
      ...> Stonecutters Seafood and Chop House, Lemont, IL, 12/19/02, Week Back
      ...> \"""
      ...> |> CsvSniffer.sniff()
      {:ok, %CsvSniffer.Dialect{
        delimiter: ",",
        quote_character: "\\"",
        double_quote: false,
        skip_initial_space: true
      }}

  """
  @doc since: "0.2.0"
  @spec sniff(sample :: String.t(), opts :: [delimiters: [String.t()]]) ::
          {:ok, Dialect.t()} | {:error, reason :: any()}
  def sniff(sample, opts \\ []) when is_binary(sample) do
    delimiters = Keyword.get(opts, :delimiters, nil)

    sample
    |> guess_quote_and_delimiter(delimiters)
    |> guess_delimiter(sample, delimiters)
    |> format_response()
  end

  # Looks for text enclosed between two identical quotes (the probable quotechar) which are
  # preceded and followed by the same character (the probable delimiter).
  #
  # For example:
  #                  ,'some text',
  # The quote with the most wins, same with the delimiter.  If there is no quotechar the delimiter
  # can't be determined this way.
  defp guess_quote_and_delimiter(sample, delimiters) do
    sample
    |> run_quote_regex()
    |> count_matches(delimiters)
    |> pick_count_winners()
    |> check_double_quote(sample)
  end

  @quote_regex [
    # ,".*?",
    ~r'(?P<delim>[^\w\n"\'])(?P<space> ?)(?P<quote>["\']).*?(?P=quote)(?P=delim)'sm,
    #  ".*?",
    ~r'(?:^|\n)(?P<quote>["\']).*?(?P=quote)(?P<delim>[^\w\n"\'])(?P<space> ?)'sm,
    # ,".*?"
    ~r'(?P<delim>[^\w\n"\'])(?P<space> ?)(?P<quote>["\']).*?(?P=quote)(?:$|\n)'sm,
    #  ".*?" (no delim, no space)
    ~r'(?:^|\n)(?P<quote>["\']).*?(?P=quote)(?:$|\n)'sm
  ]

  defp run_quote_regex(sample) do
    Enum.find_value(@quote_regex, {[], []}, fn regex ->
      case Regex.scan(regex, sample, capture: :all_names) do
        [] -> false
        matches -> {Regex.names(regex), matches}
      end
    end)
  end

  defp count_matches({names, matches}, delimiters) do
    initial_acc = %{quote: %{}, delim: %{}, space: 0}

    Enum.reduce(matches, initial_acc, fn match, acc ->
      names
      |> Enum.zip(match)
      |> reduce_zipped_matches(acc, delimiters)
    end)
  end

  defp reduce_zipped_matches(zipped_matches, acc, delimiters) do
    Enum.reduce(zipped_matches, acc, fn
      {"quote", value}, acc ->
        update_in(acc, [:quote, value], &((&1 || 0) + 1))

      {"delim", value}, acc ->
        if !delimiters || value in delimiters do
          update_in(acc, [:delim, value], &((&1 || 0) + 1))
        else
          acc
        end

      {"space", value}, acc ->
        if is_nil(value) or value == "" do
          acc
        else
          Map.update(acc, :space, 1, &((&1 || 0) + 1))
        end
    end)
  end

  defp pick_count_winners(%{quote: quotes, delim: delimiters, space: spaces}) do
    quote_character = max_by_value(quotes) || "\""
    delimiter = max_by_value(delimiters)
    skip_initial_space = delimiters[delimiter] == spaces
    non_newline_delimiter = if delimiter == "\n", do: "", else: delimiter

    %Dialect{
      delimiter: non_newline_delimiter,
      quote_character: quote_character,
      skip_initial_space: skip_initial_space
    }
  end

  defp max_by_value(map) when map == %{}, do: nil

  defp max_by_value(map) do
    map
    |> Enum.max_by(&elem(&1, 1))
    |> elem(0)
  end

  defp check_double_quote(
         %Dialect{delimiter: delimiter, quote_character: quote_character} = dialect,
         sample
       )
       when not is_nil(delimiter) and not is_nil(quote_character) do
    escaped_delimiter = Regex.escape(delimiter)
    escaped_quote_character = Regex.escape(quote_character)

    # If we see an extra quote between delimiters, we've got a double quoted format.
    double_quote_regex =
      Regex.compile!(
        "((#{escaped_delimiter})|^)\W*#{escaped_quote_character}[^#{escaped_delimiter}\n]*" <>
          "#{escaped_quote_character}[^#{escaped_delimiter}\n]*#{escaped_quote_character}\W*" <>
          "((#{escaped_delimiter})|$)",
        "m"
      )

    double_quote = Regex.match?(double_quote_regex, sample)

    %Dialect{dialect | double_quote: double_quote}
  end

  defp check_double_quote(dialect, _sample) do
    dialect
  end

  # The delimiter /should/ occur the same number of times on each row.  However, due to malformed
  # data, it may not.  We don't want an all or nothing approach, so we allow for small variations
  # in this number.
  #   1) build a table of the frequency of each character on every line.
  #   2) build a table of frequencies of this frequency (meta-frequency?), e.g. 'x occurred 5
  #      times in 10 rows, 6 times in 1000 rows, 7 times in 2 rows'
  #   3) use the mode of the meta-frequency to determine the /expected/ frequency for that
  #      character
  #   4) find out how often the character actually meets that goal
  #   5) the character that best meets its goal is the delimiter
  # For performance reasons, the data is evaluated in chunks, so it can try and evaluate the
  # smallest portion of the data possible, evaluating additional chunks as necessary.
  defp guess_delimiter(%Dialect{delimiter: nil} = dialect, sample, delimiters) do
    split_sample =
      sample
      |> String.split("\n")
      |> Stream.reject(&(String.trim(&1) == ""))

    initial_acc = %{frequency_tables: %{}, total: 0}

    delimiter =
      split_sample
      |> Stream.chunk_every(10)
      |> Enum.reduce_while(initial_acc, fn chunk,
                                           %{frequency_tables: frequency_tables, total: total} ->
        new_total = total + length(chunk)
        updated_frequency_tables = build_frequency_tables(chunk, frequency_tables)

        possible_delimiters =
          updated_frequency_tables
          |> get_mode_of_the_frequencies()
          |> build_a_list_of_possible_delimiters(new_total, delimiters)

        cont_or_halt = if possible_delimiters == %{}, do: :cont, else: :halt

        {cont_or_halt,
         %{
           frequency_tables: updated_frequency_tables,
           possible_delimiters: possible_delimiters,
           total: new_total
         }}
      end)
      |> Map.get(:possible_delimiters)
      |> pick_delimiter()

    %Dialect{
      dialect
      | delimiter: delimiter,
        skip_initial_space: skip_initial_space?(delimiter, split_sample)
    }
  end

  defp guess_delimiter(dialect, _sample, _delimiters) do
    dialect
  end

  @seven_bit_ascii Enum.into(0..127, %{}, &{&1, 0})

  defp build_frequency_tables(data, acc) do
    data
    |> Stream.map(&to_charlist/1)
    |> Stream.map(fn line ->
      Enum.reduce(line, @seven_bit_ascii, &Map.update(&2, &1, 1, fn count -> count + 1 end))
    end)
    |> Enum.reduce(acc, &reduce_frequency_tables/2)
  end

  defp reduce_frequency_tables(frequency_table, acc) do
    Enum.reduce(frequency_table, acc, fn {character, frequency}, acc ->
      Map.update(acc, character, %{frequency => 1}, fn meta_frequency ->
        Map.update(meta_frequency, frequency, 1, &(&1 + 1))
      end)
    end)
  end

  defp get_mode_of_the_frequencies(frequency_tables) do
    Enum.reduce(frequency_tables, %{}, fn
      {_character, %{0 => _} = items}, acc when map_size(items) == 1 ->
        acc

      # Limit to 7-bit ASCII characters
      {character, items}, acc when 0 <= character and character <= 127 ->
        {frequency, meta_frequency} = Enum.max_by(items, &elem(&1, 1))
        {_, remaining_items} = Map.pop(items, frequency)

        # adjust the mode - subtract the sum of all other frequencies
        adjusted_mode =
          {frequency, meta_frequency - (remaining_items |> Map.values() |> Enum.sum())}

        Map.put(acc, <<character>>, adjusted_mode)

      _character_and_frequencies, acc ->
        acc
    end)
  end

  @min_consistency_threshold 0.9

  defp build_a_list_of_possible_delimiters(modes, total, delimiters, consistency \\ 1.0) do
    possible_delimiters =
      Enum.reduce(modes, %{}, fn
        {delimiter, {frequency, meta_frequency} = value}, acc
        when frequency > 0 and meta_frequency > 0 and meta_frequency / total >= consistency ->
          if is_nil(delimiters) or delimiter in delimiters do
            Map.put(acc, delimiter, value)
          else
            acc
          end

        _delimiter_and_frequency, acc ->
          acc
      end)

    if possible_delimiters == %{} and consistency > @min_consistency_threshold do
      build_a_list_of_possible_delimiters(modes, total, delimiters, consistency - 0.01)
    else
      possible_delimiters
    end
  end

  defp pick_delimiter(possible_delimiters) when map_size(possible_delimiters) == 1 do
    possible_delimiters
    |> Map.keys()
    |> List.first()
  end

  defp pick_delimiter(possible_delimiters) when map_size(possible_delimiters) > 1 do
    pick_preferred_delimiter(possible_delimiters) ||
      max_by_value(possible_delimiters)
  end

  defp pick_delimiter(_possible_delimiters) do
    nil
  end

  defp pick_preferred_delimiter(possible_delimiters) do
    delimiters = Map.keys(possible_delimiters)
    Enum.find(@preferred, &(&1 in delimiters))
  end

  defp skip_initial_space?(delimiter, split_sample) when is_binary(delimiter) do
    line =
      split_sample
      |> Enum.take(1)
      |> List.first()

    length(String.split(line, delimiter)) == length(String.split(line, delimiter <> " "))
  end

  defp skip_initial_space?(nil, _sample) do
    false
  end

  defp format_response(%Dialect{delimiter: delimiter} = dialect) do
    case delimiter do
      nil -> {:error, "Could not determine delimiter"}
      _delimiter -> {:ok, dialect}
    end
  end
end
