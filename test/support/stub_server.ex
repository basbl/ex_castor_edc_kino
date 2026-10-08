defmodule CastorEDC.Kino.StubServer do
  @moduledoc """
  A Req adapter for the clients smart cells build themselves: it answers
  token requests, and lists studies unless the token is "refused".
  """

  def run(request) do
    response =
      case {request.url.path, Req.Request.get_header(request, "authorization")} do
        {"/oauth/token", _auth} ->
          json(%{"access_token" => "token", "expires_in" => 3600, "token_type" => "Bearer"})

        {"/api/study", ["Bearer refused"]} ->
          json(%{"status" => 401, "title" => "Unauthorized", "detail" => "Invalid token"}, 401)

        {"/api/study", _auth} ->
          json(%{
            "_embedded" => %{
              "study" => [
                %{"study_id" => "study-1", "name" => "Trial"},
                %{"study_id" => "study-2", "name" => "Registry"}
              ]
            },
            "page" => 1,
            "page_count" => 1
          })
      end

    {request, response}
  end

  defp json(body, status \\ 200), do: CastorEDC.Test.json(body, status: status)
end
