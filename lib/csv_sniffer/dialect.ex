defmodule CsvSniffer.Dialect do
  @moduledoc """
  Describes a CSV dialect.
  """
  @moduledoc since: "0.1.0"

  @typedoc "Describes a CSV dialect."
  @typedoc since: "0.1.0"
  @type t :: %__MODULE__{
          delimiter: String.t(),
          quote_character: String.t(),
          quote_needed: boolean()
        }

  defstruct delimiter: nil,
            quote_character: nil,
            quote_needed: false
end
