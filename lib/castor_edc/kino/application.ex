defmodule CastorEDC.Kino.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Kino.SmartCell.register(CastorEDC.Kino.ConnectionCell)
    Kino.SmartCell.register(CastorEDC.Kino.StudyCell)

    Supervisor.start_link([], strategy: :one_for_one, name: CastorEDC.Kino.Supervisor)
  end
end
