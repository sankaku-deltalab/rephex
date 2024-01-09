defmodule RephexTest.Fixture.TestLive.Index do
  use Phoenix.LiveView
  use Rephex.RootComponent, state: RephexTest.Fixture.CounterState
  # import Rephex.Component

  alias Phoenix.LiveView.Socket
  alias RephexTest.Fixture.CounterState

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> CounterState.init()}
  end

  @impl true
  def handle_event("add_count_1", _params, %Socket{} = socket) do
    {:noreply, socket |> CounterState.add_count(%{amount: 1})}
  end

  @impl true
  def handle_event("add_count_async_2", _params, %Socket{} = socket) do
    {:noreply, socket |> CounterState.AddCountAsync.start(%{amount: 2, delay: 1000})}
  end

  @impl true
  def handle_event("cancel_add_count_async_2", _params, %Socket{} = socket) do
    {:noreply, socket |> CounterState.AddCountAsync.cancel()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>Count: <%= @__rephex__.count %></div>

    <button phx-click="add_count_1">[Add 1]</button>
    <.async_result assign={@__rephex__.add_twice_async}>
      <:loading :let={%{progress: {current, max}}}>
        <button phx-click="cancel_add_count_async_2">[Cancel]</button>
        <%= "#{current} / #{max}" %>
      </:loading>
      <:failed :let={_reason}>failed</:failed>
      <button phx-click="add_count_async_2">[Add async 2]</button>
    </.async_result>

    <button phx-click="test_async">[test_async]</button>
    """
  end
end
