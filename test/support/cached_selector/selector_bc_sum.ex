defmodule RephexTest.Fixture.SelectorBCSum do
  @behaviour Rephex.CachedSelector.Base

  @impl true
  def args(socket) do
    {socket.assigns.b, socket.assigns.c}
  end

  @impl true
  def resolve({b, c}) do
    b + c
  end
end
