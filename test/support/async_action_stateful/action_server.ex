defmodule RephexTest.Fixture.AsyncActionStateful.ActionServer do
  import ExUnit.Assertions
  alias Phoenix.LiveView.Socket

  @type state :: %{
          socket: Socket.t(),
          time_ms: integer()
        }

  import Mox
  use GenServer
  alias Rephex.AsyncAction.Backend
  alias RephexTest.Fixture.AsyncActionStateful.LiveView

  def start_link() do
    {:ok, socket} = LiveView.mount(%{}, %{}, %Socket{})
    state = %{socket: socket, time_ms: -9999}

    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def init(init_arg), do: {:ok, init_arg}

  def stop() do
    GenServer.stop(__MODULE__)
  end

  def start_single(action_module, payload) do
    result_path = [:result_single]

    fn state ->
      start_async_stub({action_module, result_path})
      socket = action_module.start(state.socket, payload)
      {:reply, socket, %{state | socket: socket}}
    end
    |> call_fun()
  end

  def start_multi({action_module, key}, payload) do
    result_path = [:result_multi, key]

    fn state ->
      start_async_stub({action_module, result_path})
      socket = action_module.start(state.socket, key, payload)
      {:reply, socket, %{state | socket: socket}}
    end
    |> call_fun()
  end

  defp start_async_stub({action_module, result_path}) do
    Rephex.Api.MockLiveViewApi
    |> stub(
      :start_async,
      fn socket, {Backend, :start_async, {m, r}}, _fun ->
        assert {m, r} == {action_module, result_path}
        socket
      end
    )
  end

  def async_process_update_progress({action_module, result_path}, progress) do
    fn state ->
      {:noreply, socket} =
        gen_update_progress_message({action_module, result_path}, progress)
        |> LiveView.handle_info(state.socket)

      {:reply, socket, %{state | socket: socket}}
    end
    |> call_fun()
  end

  def async_process_resolved({action_module, result_path}, result) do
    fn state ->
      {:noreply, socket} =
        gen_start_async_name({action_module, result_path})
        |> LiveView.handle_async(result, state.socket)

      {:reply, socket, %{state | socket: socket}}
    end
    |> call_fun()
  end

  def cancel_single(action_module, reason) do
    result_path = [:result_single]

    fn state ->
      cancel_expect({action_module, result_path}, reason)
      socket = action_module.cancel(state.socket, reason)
      {:reply, socket, %{state | socket: socket}}
    end
    |> call_fun()
  end

  def cancel_multi({action_module, key}, reason) do
    result_path = [:result_multi, key]

    fn state ->
      cancel_expect({action_module, result_path}, reason)
      socket = action_module.cancel(state.socket, key, reason)
      {:reply, socket, %{state | socket: socket}}
    end
    |> call_fun()
  end

  def consume_time(time_ms) do
    fn state ->
      {:reply, state.time_ms, %{state | time_ms: state.time_ms + time_ms}}
    end
    |> call_fun()
  end

  defp cancel_expect({action_module, result_path}, reason) do
    Rephex.Api.MockLiveViewApi
    |> expect(
      :cancel_async,
      fn socket, {Backend, :start_async, {m, r}}, re ->
        assert {m, r, re} == {action_module, result_path, reason}
        socket
      end
    )
  end

  defp gen_update_progress_message({action_module, result_path}, progress) do
    {Rephex.AsyncAction.Backend, :update_progress, {action_module, result_path}, progress}
  end

  defp gen_start_async_name({action_module, result_path}) do
    {Rephex.AsyncAction.Backend, :start_async, {action_module, result_path}}
  end

  defp call_fun(fun) do
    GenServer.call(__MODULE__, {:call_fun, fun})
  end

  def handle_call({:call_fun, fun}, _from, state) do
    Rephex.Api.MockSystemApi
    |> stub(
      :monotonic_time,
      fn :millisecond -> state.time_ms end
    )

    fun.(state)
  end
end
