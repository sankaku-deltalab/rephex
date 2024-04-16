defmodule RephexTest.Fixture.AsyncActionStateful.LiveView do
  use Phoenix.LiveView
  use Rephex.LiveView

  alias RephexTest.Fixture.AsyncActionStateful.State

  @impl true
  def mount(_params, _session, socket) do
    {:ok, State.init(socket)}
  end
end
