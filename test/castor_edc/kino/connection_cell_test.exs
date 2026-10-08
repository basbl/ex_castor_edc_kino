defmodule CastorEDC.Kino.ConnectionCellTest do
  # Not async: the tests set Livebook secrets, which are environment variables.
  use ExUnit.Case, async: false

  import Kino.Test

  alias CastorEDC.Kino.ConnectionCell

  setup :configure_livebook_bridge

  setup do
    Application.put_env(:ex_castor_edc_kino, :client_options, adapter: CastorEDC.Kino.StubServer, retry: false)
    secrets = ~w(LB_CASTOR_EDC_CLIENT_ID LB_CASTOR_EDC_CLIENT_SECRET LB_CASTOR_EDC_ACCESS_TOKEN LB_OTHER_TOKEN)

    on_exit(fn ->
      Application.delete_env(:ex_castor_edc_kino, :client_options)
      Enum.each(secrets, &System.delete_env/1)
    end)
  end

  test "builds a client from Livebook secrets for data.castoredc.com by default" do
    {_kino, source} = start_smart_cell!(ConnectionCell, %{})

    assert source == """
           client =
             CastorEDC.new(
               client_id: System.fetch_env!("LB_CASTOR_EDC_CLIENT_ID"),
               client_secret: System.fetch_env!("LB_CASTOR_EDC_CLIENT_SECRET"),
               base_url: "https://data.castoredc.com"
             )\
           """
  end

  test "takes an access token and another server instead" do
    {kino, _source} = start_smart_cell!(ConnectionCell, %{})

    push_event(kino, "update_field", %{"field" => "auth", "value" => "token"})
    push_event(kino, "update_field", %{"field" => "server", "value" => "custom"})
    push_event(kino, "update_field", %{"field" => "custom_server", "value" => " https://edc.example.org "})
    push_event(kino, "update_field", %{"field" => "variable", "value" => "castor"})

    assert_smart_cell_update(
      kino,
      %{"auth" => "token", "server" => "custom", "variable" => "castor"},
      """
      castor =
        CastorEDC.new(
          access_token: System.fetch_env!("LB_CASTOR_EDC_ACCESS_TOKEN"),
          base_url: "https://edc.example.org"
        )\
      """
    )
  end

  test "keeps the variable name when the new one isn't valid" do
    {kino, _source} = start_smart_cell!(ConnectionCell, %{"variable" => "castor"})
    push_event(kino, "update_field", %{"field" => "variable", "value" => "1 bad"})
    assert_broadcast_event(kino, "update", %{"fields" => %{"variable" => "castor"}})
  end

  test "restores its fields" do
    attrs = %{"auth" => "token", "access_token_secret" => "OTHER_TOKEN", "server" => "https://us.castoredc.com"}
    {_kino, source} = start_smart_cell!(ConnectionCell, attrs)
    assert source =~ ~s{access_token: System.fetch_env!("LB_OTHER_TOKEN")}
    assert source =~ ~s{base_url: "https://us.castoredc.com"}
  end

  describe "testing the connection" do
    test "lists the studies the secrets give access to" do
      System.put_env("LB_CASTOR_EDC_CLIENT_ID", "id")
      System.put_env("LB_CASTOR_EDC_CLIENT_SECRET", "secret")

      {kino, _source} = start_smart_cell!(ConnectionCell, %{"server" => "https://edc.test"})
      push_event(kino, "test", %{})
      assert_broadcast_event(kino, "test", %{"ok" => true, "message" => "Connected: 2 studies available."})

      assert %{test: %{"ok" => true}} = connect(kino)
    end

    test "shows the API's error" do
      System.put_env("LB_OTHER_TOKEN", "refused")

      {kino, _source} =
        start_smart_cell!(ConnectionCell, %{
          "auth" => "token",
          "access_token_secret" => "OTHER_TOKEN",
          "server" => "https://edc.test"
        })

      push_event(kino, "test", %{})
      assert_broadcast_event(kino, "test", %{"ok" => false, "message" => "Invalid token"})
    end

    test "names the secrets the notebook doesn't have" do
      {kino, _source} = start_smart_cell!(ConnectionCell, %{})
      push_event(kino, "test", %{})

      assert_broadcast_event(kino, "test", %{
        "ok" => false,
        "message" =>
          "This notebook has no secret CASTOR_EDC_CLIENT_ID and CASTOR_EDC_CLIENT_SECRET; add it in the notebook's secrets."
      })
    end
  end

  test "is registered with Livebook" do
    assert Enum.any?(Kino.SmartCell.definitions(), &match?(%{module: ConnectionCell, name: "Castor EDC connection"}, &1))
  end
end
