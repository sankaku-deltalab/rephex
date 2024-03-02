defmodule RephexTest.Fixture.AsyncActionStateful.ActionServer do
  import ExUnit.Assertions
  alias Phoenix.LiveView.Socket

  @type state :: %{
          socket: Socket.t()
        }

  import Mox
  use GenServer
  alias Rephex.AsyncAction.Backend
  alias RephexTest.Fixture.AsyncActionStateful.{Action, LiveView}

  def start_link() do
    {:ok, socket} = LiveView.mount(%{}, %{}, %Socket{})
    state = %{socket: socket}

    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def init(init_arg), do: {:ok, init_arg}

  def stop() do
    GenServer.stop(__MODULE__)
  end

  def start(result_path, payload) do
    fn state ->
      Rephex.Api.MockLiveViewApi
      |> stub(
        :start_async,
        fn socket, {Backend, :start_async, Action, ^result_path}, fun ->
          # Check Action.start_async returns
          assert {_state, ^result_path, ^payload, _update_progress} = fun.()
          socket
        end
      )

      socket = Action.start(state.socket, payload)
      {:reply, socket, %{state | socket: socket}}
    end
    |> call_fun()
  end

  def async_process_update_progress(result_path, progress) do
    fn state ->
      {:noreply, socket} =
        gen_update_progress_message(Action, result_path, progress)
        |> LiveView.handle_info(state.socket)

      {:reply, socket, %{state | socket: socket}}
    end
    |> call_fun()
  end

  def async_process_resolved(result_path, result) do
    fn state ->
      {:noreply, socket} =
        gen_start_async_name(Action, result_path)
        |> LiveView.handle_async(result, state.socket)

      {:reply, socket, %{state | socket: socket}}
    end
    |> call_fun()
  end

  def cancel(result_path, reason) do
    fn state ->
      Rephex.Api.MockLiveViewApi
      |> expect(
        :cancel_async,
        fn socket, {Backend, :start_async, Action, ^result_path}, ^reason ->
          socket
        end
      )

      socket = Action.cancel(state.socket, reason)

      {:reply, socket, %{state | socket: socket}}
    end
    |> call_fun()
  end

  def handle_call({:call_fun, fun}, _from, state) do
    fun.(state)
  end

  defp gen_update_progress_message(action_module, result_path, progress) do
    {Rephex.AsyncAction.Backend, :update_progress, action_module, result_path, progress}
  end

  defp gen_start_async_name(action_module, result_path) do
    {Rephex.AsyncAction.Backend, :start_async, action_module, result_path}
  end

  defp call_fun(fun) do
    GenServer.call(__MODULE__, {:call_fun, fun})
  end
end
