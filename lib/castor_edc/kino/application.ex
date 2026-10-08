defmodule CastorEDC.Kino.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Kino.SmartCell.register(CastorEDC.Kino.ConnectionCell)
    Kino.SmartCell.register(CastorEDC.Kino.StudyCell)
    Kino.SmartCell.register(CastorEDC.Kino.DataCell)
    Kino.SmartCell.register(CastorEDC.Kino.ExportCell)

    Supervisor.start_link([], strategy: :one_for_one, name: CastorEDC.Kino.Supervisor)
  end
end
