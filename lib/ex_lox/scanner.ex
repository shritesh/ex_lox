defmodule ExLox.Scanner do
  alias __MODULE__
  alias ExLox.Token

  @type t :: %Scanner{
          tokens: list(Token.t()),
          errors: list(ExLox.error()),
          line: non_neg_integer()
        }
  defstruct tokens: [],
            errors: [],
            line: 1

  @type result :: {:ok, list(Token.t())} | {:error, list(ExLox.error())}

  @spec scan(String.t()) :: result()
  def scan(source) do
    chars = String.to_charlist(source)
    scan(%Scanner{}, chars)
  end

  defguardp is_whitespace(char) when char in [?\s, ?\r, ?\t]
  defguardp is_digit(char) when char in ?0..?9
  defguardp is_alpha(char) when char in ?a..?z or char in ?A..?Z or char == ?_
  defguardp is_alphanumeric(char) when is_alpha(char) or is_digit(char)

  @spec scan(t(), charlist()) :: result()
  defp scan(%Scanner{errors: [], tokens: tokens}, []) do
    tokens = Enum.reverse(tokens)
    {:ok, tokens}
  end

  defp scan(%Scanner{errors: errors}, []) do
    errors = Enum.reverse(errors)
    {:error, errors}
  end

  defp scan(scanner, chars) do
    case chars do
      [?( | rest] ->
        scanner
        |> add_token(:left_paren)
        |> scan(rest)

      [?) | rest] ->
        scanner
        |> add_token(:right_paren)
        |> scan(rest)

      [?{ | rest] ->
        scanner
        |> add_token(:left_brace)
        |> scan(rest)

      [?} | rest] ->
        scanner
        |> add_token(:right_brace)
        |> scan(rest)

      [?, | rest] ->
        scanner
        |> add_token(:comma)
        |> scan(rest)

      [?. | rest] ->
        scanner
        |> add_token(:dot)
        |> scan(rest)

      [?- | rest] ->
        scanner
        |> add_token(:minus)
        |> scan(rest)

      [?+ | rest] ->
        scanner
        |> add_token(:plus)
        |> scan(rest)

      [?; | rest] ->
        scanner
        |> add_token(:semicolon)
        |> scan(rest)

      [?* | rest] ->
        scanner
        |> add_token(:star)
        |> scan(rest)

      [?!, ?= | rest] ->
        scanner
        |> add_token(:bang_equal)
        |> scan(rest)

      [?! | rest] ->
        scanner
        |> add_token(:bang)
        |> scan(rest)

      [?=, ?= | rest] ->
        scanner
        |> add_token(:equal_equal)
        |> scan(rest)

      [?= | rest] ->
        scanner
        |> add_token(:equal)
        |> scan(rest)

      [?<, ?= | rest] ->
        scanner
        |> add_token(:less_equal)
        |> scan(rest)

      [?< | rest] ->
        scanner
        |> add_token(:less)
        |> scan(rest)

      [?>, ?= | rest] ->
        scanner
        |> add_token(:greater_equal)
        |> scan(rest)

      [?> | rest] ->
        scanner
        |> add_token(:greater)
        |> scan(rest)

      [?/, ?/ | rest] ->
        rest = Enum.drop_while(rest, &(&1 != ?\n))

        scanner
        |> scan(rest)

      [?/ | rest] ->
        scanner
        |> add_token(:slash)
        |> scan(rest)

      [?\n] ->
        scanner
        |> scan([])

      [?\n | rest] ->
        scanner
        |> inc_line()
        |> scan(rest)

      [?" | rest] ->
        scanner
        |> scan_string([], rest)

      [c | rest] when is_whitespace(c) ->
        scanner
        |> scan(rest)

      [c | rest] when is_digit(c) ->
        scanner
        |> scan_number([c | rest])

      [c | rest] when is_alpha(c) ->
        scanner
        |> scan_identifier([c | rest])

      [c | rest] ->
        scanner
        |> add_error("Unexpected character: '#{<<c>>}'")
        |> scan(rest)
    end
  end

  @spec add_token(t(), Token.type()) :: t()
  defp add_token(scanner, token_type) do
    token = Token.new(token_type, scanner.line)
    %{scanner | tokens: [token | scanner.tokens]}
  end

  @spec add_error(t(), String.t()) :: t()
  defp add_error(scanner, message) do
    error = {scanner.line, message}
    %{scanner | errors: [error | scanner.errors]}
  end

  @spec inc_line(t()) :: t()
  defp inc_line(scanner) do
    %{scanner | line: scanner.line + 1}
  end

  @spec scan_string(t(), charlist(), charlist()) :: result()
  defp scan_string(scanner, string, chars) do
    case chars do
      [?" | rest] ->
        string = string |> Enum.reverse() |> to_string()

        scanner
        |> add_token({:string, string})
        |> scan(rest)

      [?\n | rest] ->
        scanner
        |> inc_line()
        |> scan_string([?\n | string], rest)

      [] ->
        scanner
        |> add_error("Unterminated String")
        |> scan([])

      [char | rest] ->
        scanner
        |> scan_string([char | string], rest)
    end
  end

  @spec scan_number(t(), charlist()) :: result()
  defp scan_number(scanner, chars) do
    {digits, rest} =
      case Enum.split_while(chars, &is_digit/1) do
        {digits, [?. | rest]} ->
          {decimals, rest} = Enum.split_while(rest, &is_digit/1)

          {digits ++ '.' ++ decimals, rest}

        {digits, rest} ->
          {digits, rest}
      end

    {number, _} =
      digits
      |> to_string()
      |> Float.parse()

    scanner
    |> add_token({:number, number})
    |> scan(rest)
  end

  @spec scan_identifier(t(), charlist()) :: result()
  defp scan_identifier(scanner, chars) do
    {text, rest} = Enum.split_while(chars, &is_alphanumeric/1)

    type =
      case to_string(text) do
        "and" -> :and
        "class" -> :class
        "else" -> :else
        "false" -> false
        "for" -> :for
        "fun" -> :fun
        "if" -> :if
        "nil" -> nil
        "or" -> :or
        "print" -> :print
        "return" -> :return
        "super" -> :super
        "this" -> :this
        "true" -> true
        "var" -> :var
        "while" -> :while
        identifier -> {:identifier, identifier}
      end

    scanner
    |> add_token(type)
    |> scan(rest)
  end
end
