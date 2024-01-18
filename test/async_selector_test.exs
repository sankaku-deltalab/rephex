defmodule RephexTest.AsyncSelectorTest do
  use ExUnit.Case

  alias Phoenix.LiveView.AsyncResult
  alias RephexTest.Fixture
  alias RephexTest.Fixture.AsyncSelectorABSum
  alias Rephex.Selector.AsyncSelector

  test "new" do
    ab_sum = AsyncSelector.new(AsyncSelectorABSum, init: 999)

    assert ab_sum.async == AsyncResult.ok(999)
    assert ab_sum.prev_args == {AsyncSelector, :__undefined__}
    assert ab_sum.selector_module == AsyncSelectorABSum
  end

  test "update_in_socket" do
    ab_sum = AsyncSelector.new(AsyncSelectorABSum, init: 999)

    socket =
      Fixture.new_socket_raw()
      |> Phoenix.Component.assign(%{a: 1, b: 2, ab_sum: ab_sum})
      |> AsyncSelector.update_in_socket([:ab_sum])

    ab_sum = socket.assigns.ab_sum

    # update will caused by async
    assert ab_sum.async == AsyncResult.ok(999) |> AsyncResult.loading()
    assert ab_sum.prev_args == {1, 2}
  end

  test "resolve_in_socket - ok" do
    ab_sum = AsyncSelector.new(AsyncSelectorABSum, init: 999)

    socket =
      Fixture.new_socket_raw()
      |> Phoenix.Component.assign(%{a: 1, b: 2, ab_sum: ab_sum})
      |> AsyncSelector.update_in_socket([:ab_sum])
      |> AsyncSelector.resolve_in_socket([:ab_sum], {:ok, 3})

    ab_sum = socket.assigns.ab_sum

    assert ab_sum.async == AsyncResult.ok(999) |> AsyncResult.loading() |> AsyncResult.ok(3)
    assert ab_sum.prev_args == {1, 2}
  end
end
