defmodule RephexTest.CachedSelectorTest do
  use ExUnit.Case

  alias RephexTest.Fixture
  alias Rephex.CachedSelector

  test "new" do
    _ab_sum =
      CachedSelector.new(
        fn socket -> [socket.assigns.a, socket.assigns.b] end,
        fn [a, b] -> a + b end
      )

    # no exception
  end

  test "update" do
    ab_sum =
      CachedSelector.new(
        fn socket -> [socket.assigns.a, socket.assigns.b] end,
        fn [a, b] -> a + b end
      )

    socket =
      Fixture.new_socket_raw()
      |> Phoenix.Component.assign(%{a: 1, b: 2})

    ab_sum = CachedSelector.update(ab_sum, socket)
    assert ab_sum.result == 1 + 2
    assert ab_sum.prev_args == [1, 2]
  end

  test "update_selectors_in_socket update selectors not nested" do
    initial_state = %{
      ab_sum:
        CachedSelector.new(
          fn socket -> [socket.assigns.a, socket.assigns.b] end,
          fn [a, b] -> a + b end
        ),
      bc_sum:
        CachedSelector.new(
          fn socket -> [socket.assigns.b, socket.assigns.c] end,
          fn [b, c] -> b + c end
        )
    }

    socket =
      Fixture.new_socket_raw()
      |> Phoenix.Component.assign(initial_state)
      |> Phoenix.Component.assign(%{a: 1, b: 2, c: 3})
      |> CachedSelector.update_selectors_in_socket()

    ab_sum = socket.assigns.ab_sum
    bc_sum = socket.assigns.bc_sum
    assert ab_sum.result == 1 + 2
    assert bc_sum.result == 2 + 3
  end

  test "do not update selectors nested" do
    initial_state = %{
      nest: %{
        ab_sum:
          CachedSelector.new(
            fn socket -> [socket.assigns.a, socket.assigns.b] end,
            fn [a, b] -> a + b end
          ),
        bc_sum:
          CachedSelector.new(
            fn socket -> [socket.assigns.b, socket.assigns.c] end,
            fn [b, c] -> b + c end
          )
      }
    }

    socket =
      Fixture.new_socket_raw()
      |> Phoenix.Component.assign(initial_state)
      |> Phoenix.Component.assign(%{a: 1, b: 2, c: 3})
      |> CachedSelector.update_selectors_in_socket()

    ab_sum = socket.assigns.nest.ab_sum
    bc_sum = socket.assigns.nest.bc_sum
    assert ab_sum.result == nil
    assert bc_sum.result == nil
  end
end
