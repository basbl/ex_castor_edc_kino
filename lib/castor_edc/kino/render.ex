defimpl Kino.Render, for: CastorEDC.Page do
  def to_livebook(page), do: page |> CastorEDC.Kino.page() |> Kino.Render.to_livebook()
end

defimpl Kino.Render, for: CastorEDC.Error do
  def to_livebook(error), do: error |> CastorEDC.Kino.error() |> Kino.Render.to_livebook()
end

defimpl Kino.Render, for: CastorEDC.Export do
  def to_livebook(export), do: export |> CastorEDC.Kino.export() |> Kino.Render.to_livebook()
end

defimpl Kino.Render, for: [CastorEDC.MissingValue, CastorEDC.PartialDate] do
  def to_livebook(value), do: value |> CastorEDC.Kino.value() |> Kino.Render.to_livebook()
end

# Every struct under CastorEDC.Model, which the generator writes, so the
# list comes from the library's own modules when this file compiles.
models =
  with :ok <-
         (case Application.load(:ex_castor_edc) do
            :ok -> :ok
            {:error, {:already_loaded, _app}} -> :ok
          end),
       {:ok, modules} <- :application.get_key(:ex_castor_edc, :modules) do
    Enum.filter(modules, &String.starts_with?(Atom.to_string(&1), "Elixir.CastorEDC.Model."))
  end

for model <- models do
  defimpl Kino.Render, for: model do
    def to_livebook(record), do: record |> CastorEDC.Kino.record() |> Kino.Render.to_livebook()
  end
end
