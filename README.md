# CastorEDC.Kino

[Livebook](https://livebook.dev) integration for [ex_castor_edc](https://github.com/basbl/ex_castor_edc): the library's results render as tables and trees instead of raw terms.

It only reads: nothing in it changes a study.

## Installation

```elixir
Mix.install([
  {:ex_castor_edc_kino, "~> 0.1.0"}
])
```

## Usage

With the package installed, results render by themselves:

```elixir
client = CastorEDC.new(client_id: "...", client_secret: "...")

# A table of the participants, with the raw page in a second tab.
CastorEDC.Participants.list_participants!(client, study_id)

# A tree of one participant.
CastorEDC.Participants.get_participant!(client, study_id, "110001")
```

Errors show their message, status, code and details.
`CastorEDC.Kino.page/1`, `record/1` and `error/1` build the same views, to place them in other layouts.
