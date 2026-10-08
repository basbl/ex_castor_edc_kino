defmodule CastorEDC.Kino.Binding do
  @moduledoc false
  # What the smart cells look for in a notebook's binding.

  @uuid ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

  @doc false
  # The clients CastorEDC.new/1 builds, by variable name. They carry the
  # library's user agent.
  @spec clients(Code.binding()) :: %{String.t() => Req.Request.t()}
  def clients(binding),
    do: for({name, value} <- binding, is_atom(name), client?(value), into: %{}, do: {Atom.to_string(name), value})

  @doc false
  # The variables holding a study ID: a UUID string.
  @spec study_ids(Code.binding()) :: [String.t()]
  def study_ids(binding) do
    for {name, value} <- binding, is_atom(name), is_binary(value), value =~ @uuid, do: Atom.to_string(name)
  end

  defp client?(%Req.Request{options: %{user_agent: "ex_castor_edc/" <> _version}}), do: true
  defp client?(_value), do: false
end
