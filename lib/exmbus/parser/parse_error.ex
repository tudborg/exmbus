defmodule Exmbus.Parser.ParseError do
  defexception [:message, :errors]

  def message(t) do
    "#{t.message}. reasons=#{inspect(t.errors)}"
  end
end
