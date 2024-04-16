defmodule RephexTest.State.Assigns do
  use ExUnit.Case
  use RephexTest.PropCheck
  import Mox

  alias RephexTest.Fixture.State

  setup :verify_on_exit!

  alias Rephex.State.Assigns

  describe "update_state" do
    test "update whole state" do
      socket =
        %Phoenix.LiveView.Socket{}
        |> State.init()
        |> merge_rpx(%{v: 1})
        |> Assigns.update_state(fn %{v: v} -> %{v: v + 1} end)

      assert socket.assigns.rpx == %{v: 2}
    end

    test "raise error if socket is used in LiveComponent" do
      socket = %Phoenix.LiveView.Socket{parent_pid: self()} |> State.init()

      assert_raise RuntimeError, fn ->
        Assigns.update_state(socket, fn x -> x end)
      end
    end
  end

  describe "put_state_in" do
    property "put new item to nested path" do
      forall [
        {nested_map, path, _path_not_exist} <- gen_nested_map(),
        last_path <- term(),
        item <- term()
      ] do
        socket = %Phoenix.LiveView.Socket{} |> State.init() |> merge_rpx(nested_map)

        put_path = path ++ [last_path]
        socket = Assigns.put_state_in(socket, put_path, item)

        assert get_in(socket.assigns.rpx, put_path) == item
      end
    end

    property "replace item to nested path" do
      forall [
        {nested_map, path, _path_not_exist} <- gen_nested_map(),
        item <- term()
      ] do
        socket = %Phoenix.LiveView.Socket{} |> State.init() |> merge_rpx(nested_map)

        put_path = path
        socket = Assigns.put_state_in(socket, put_path, item)

        assert get_in(socket.assigns.rpx, put_path) == item
      end
    end

    property "raise error if nested path is not exist" do
      forall [
        {nested_map, _path, path_not_exist} <- gen_nested_map(),
        last_path <- term(),
        item <- term()
      ] do
        socket = %Phoenix.LiveView.Socket{} |> State.init() |> merge_rpx(nested_map)

        put_path = path_not_exist ++ [last_path]

        assert_raise ArgumentError, fn ->
          Assigns.put_state_in(socket, put_path, item)
        end

        true
      end
    end
  end

  describe "update_state_in" do
    property "replace item in nested path" do
      forall [
        {nested_map, path, _path_not_exist} <- gen_nested_map(),
        original_value <- term()
      ] do
        socket = %Phoenix.LiveView.Socket{} |> State.init() |> merge_rpx(nested_map)

        socket =
          socket
          |> Assigns.put_state_in(path, original_value)
          |> Assigns.update_state_in(path, &{:updated_by_test, &1})

        assert get_in(socket.assigns.rpx, path) == {:updated_by_test, original_value}
      end
    end

    property "raise error if nested path is not exist" do
      forall [
        {nested_map, _path, path_not_exist} <- gen_nested_map(),
        last_path <- term()
      ] do
        socket = %Phoenix.LiveView.Socket{} |> State.init() |> merge_rpx(nested_map)

        path = path_not_exist ++ [last_path]

        assert_raise ArgumentError, fn ->
          Assigns.put_state_in(socket, path, fn _ -> %{} end)
        end

        true
      end
    end
  end

  defp merge_rpx(socket, injected_map) do
    new_rpx = Map.merge(socket.assigns.rpx, injected_map)
    new_assigns = %{socket.assigns | rpx: new_rpx}
    %Phoenix.LiveView.Socket{socket | assigns: new_assigns}
  end

  defp gen_nested_map() do
    # Generate e.g. {%{a: %{b: %{c: %{}}}}, [:a, :b, :c], [:d, :e]}
    gen =
      let [path_exist <- non_empty(list()), path_not_exist <- non_empty(list())] do
        nested_map =
          path_exist
          |> Enum.reverse()
          |> Enum.reduce(nil, fn key, acc ->
            case acc do
              nil -> %{key => %{}}
              _ -> %{key => acc}
            end
          end)

        {nested_map, path_exist, path_not_exist}
      end

    such_that(
      {nested_map, _path_exist, path_not_exist} <- gen,
      when: path_not_exist == [] or get_in(nested_map, path_not_exist) == nil
    )
  end
end
