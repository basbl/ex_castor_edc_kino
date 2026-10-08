defmodule CastorEDC.Kino.StudyCellTest do
  use ExUnit.Case, async: true

  import Kino.Test

  alias CastorEDC.Kino.StudyCell

  setup :configure_livebook_bridge

  @studies %{
    "_embedded" => %{
      "study" => [%{"study_id" => "study-2", "name" => "registry"}, %{"study_id" => "study-1", "name" => "Trial"}]
    },
    "page" => 1,
    "page_count" => 1
  }

  defp client(response \\ CastorEDC.Test.json(@studies)), do: CastorEDC.Test.client(response)

  test "finds the notebook's clients and lists the first one's studies" do
    {kino, ""} = start_smart_cell!(StudyCell, %{})

    StudyCell.scan_binding(kino.pid, [other: 1, req: Req.new(), zclient: client(), client: client()], __ENV__)

    assert_broadcast_event(kino, "update", %{
      clients: ["client", "zclient"],
      fields: %{"client" => "client"},
      studies: [%{id: "study-2", name: "registry"}, %{id: "study-1", name: "Trial"}],
      status: nil
    })
  end

  test "binds the chosen study's ID, with its name as a comment" do
    {kino, ""} = start_smart_cell!(StudyCell, %{})
    StudyCell.scan_binding(kino.pid, [client: client()], __ENV__)
    assert_broadcast_event(kino, "update", %{studies: [_registry, _trial]})

    push_event(kino, "update_field", %{"field" => "study_id", "value" => "study-1"})
    push_event(kino, "update_field", %{"field" => "variable", "value" => "trial"})

    assert_smart_cell_update(kino, %{"study_id" => "study-1", "study_name" => "Trial", "variable" => "trial"}, """
    # Trial
    trial = "study-1"\
    """)
  end

  test "keeps a valid variable name" do
    {kino, _source} = start_smart_cell!(StudyCell, %{"study_id" => "study-1"})
    push_event(kino, "update_field", %{"field" => "variable", "value" => "not valid"})
    assert_broadcast_event(kino, "update", %{fields: %{"variable" => "study_id"}})
  end

  test "restores the chosen study without a client" do
    {_kino, source} = start_smart_cell!(StudyCell, %{"study_id" => "study-1", "study_name" => "", "variable" => "id"})
    assert source == ~s(id = "study-1")
  end

  test "lists another client's studies when it's chosen, and again on refresh" do
    other =
      client(CastorEDC.Test.json(%{@studies | "_embedded" => %{"study" => [%{"study_id" => "s-9", "name" => "Other"}]}}))

    {kino, ""} = start_smart_cell!(StudyCell, %{})
    StudyCell.scan_binding(kino.pid, [a: client(), b: other], __ENV__)
    assert_broadcast_event(kino, "update", %{studies: [_registry, _trial]})

    push_event(kino, "update_field", %{"field" => "client", "value" => "b"})
    assert_broadcast_event(kino, "update", %{fields: %{"client" => "b"}, studies: [%{id: "s-9"}]})

    push_event(kino, "refresh", %{})
    assert_broadcast_event(kino, "update", %{status: "Listing the studies…"})
    assert_broadcast_event(kino, "update", %{studies: [%{id: "s-9"}], status: nil})
  end

  test "shows why the studies couldn't be listed" do
    failing = client(CastorEDC.Test.json(%{"detail" => "Forbidden"}, status: 403))
    {kino, ""} = start_smart_cell!(StudyCell, %{})
    StudyCell.scan_binding(kino.pid, [client: failing], __ENV__)
    assert_broadcast_event(kino, "update", %{studies: [], status: "Forbidden"})
  end

  test "waits for a client" do
    {kino, ""} = start_smart_cell!(StudyCell, %{})
    StudyCell.scan_binding(kino.pid, [other: 1], __ENV__)
    assert_broadcast_event(kino, "update", %{clients: [], studies: []})
  end
end
