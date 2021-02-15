defmodule ExLox.Token do
  alias __MODULE__

  @type type ::
          :left_paren
          | :right_paren
          | :left_brace
          | :right_brace
          | :comma
          | :dot
          | :minus
          | :plus
          | :semicolon
          | :slash
          | :star
          | :bang
          | :bang_equal
          | :equal
          | :equal_equal
          | :greater
          | :greater_equal
          | :less
          | :less_equal
          | {:identifier, String.t()}
          | {:string, String.t()}
          | {:number, float()}
          | :and
          | :class
          | :else
          | false
          | :fun
          | :for
          | :if
          | nil
          | :or
          | :print
          | :return
          | :super
          | :this
          | true
          | :var
          | :while

  @type t :: %Token{
          type: type(),
          line: non_neg_integer()
        }

  @enforce_keys [:type, :line]
  defstruct [:type, :line]

  @spec new(type(), non_neg_integer()) :: t()
  def new(type, line) do
    %Token{
      type: type,
      line: line
    }
  end
end
