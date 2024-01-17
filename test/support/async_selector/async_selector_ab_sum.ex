defmodule RephexTest.Fixture.AsyncSelectorABSum do
  @behaviour Rephex.Selector.AsyncSelector.Base

  @impl true
  def args(socket) do
    {socket.assigns.a, socket.assigns.b}
  end

  @impl true
  def resolve({a, b}) do
    a + b
  end
end
