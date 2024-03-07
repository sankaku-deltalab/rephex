defmodule RephexTest.AsyncActionMultiStatefulTest do
  use ExUnit.Case
  use RephexTest.PropCheck
  use PropCheck.StateM
  import Mox

  setup :verify_on_exit!

  alias Rephex.State.Assigns
  alias RephexTest.Fixture.AsyncActionStateful.{ActionMultiServer, ModelMulti, State}

  property "Rephex.AsyncActionMulti stateful test", [:verbose] do
    forall cmds <- commands(__MODULE__) do
      {:ok, _pid} = ActionMultiServer.start_link()
      {history, state, result} = run_commands(__MODULE__, cmds)
      ActionMultiServer.stop()

      (result == :ok)
      |> when_fail(
        IO.puts("""
        ---
        history:
        #{history |> Enum.map(&inspect/1) |> Enum.map(&(&1 <> "\n---\n"))}
        ---
        state:
        #{inspect(state)}
        ---
        result:
        #{inspect(result, width: 120)}
        ---
        """)
      )
    end
  end

  @impl true
  def initial_state() do
    ModelMulti.new()
  end

  @impl true
  def command(state) do
    running_result_path_list =
      state.running_payloads
      |> Enum.map(fn {result_path, _payload} -> result_path end)

    static_items = [
      {12, {:call, ActionMultiServer, :start, [gen_result_path(), gen_payload()]}}
    ]

    dynamic_items =
      if running_result_path_list == [] do
        []
      else
        [
          {12,
           {:call, ActionMultiServer, :async_process_update_progress,
            [oneof(running_result_path_list), gen_progress()]}},
          {12,
           {:call, ActionMultiServer, :async_process_resolved,
            [oneof(running_result_path_list), gen_resolve_result()]}},
          {12,
           {:call, ActionMultiServer, :cancel,
            [oneof(running_result_path_list), gen_cancel_reason()]}}
        ]
      end

    frequency(static_items ++ dynamic_items)
  end

  def gen_result_path() do
    let key <- term() do
      [:result_2, key]
    end
  end

  def gen_payload() do
    let [bsa <- pos_integer(), ra <- pos_integer()] do
      %{
        before_start_amount: bsa,
        resolve_amount: ra
      }
    end
  end

  def gen_progress(), do: term()

  def gen_resolve_result() do
    frequency([
      {12, {:ok, gen_success_result()}},
      {6, {:exit, term()}},
      {6, {:exit, gen_cancel_reason()}}
    ])
  end

  def gen_success_result() do
    let [resolved <- pos_integer(), after_resolve <- pos_integer()] do
      %{resolved: resolved, after_resolve: after_resolve}
    end
  end

  def gen_cancel_reason() do
    frequency([
      {12, {:shutdown, utf8()}},
      {12, {:shutdown, atom()}}
    ])
  end

  @impl true
  def precondition(%ModelMulti{}, _) do
    true
  end

  @impl true
  def next_state(
        %ModelMulti{} = state,
        _res,
        {:call, ActionMultiServer, :start, [result_path, payload]}
      ) do
    ModelMulti.start(state, result_path, payload)
  end

  @impl true
  def next_state(
        %ModelMulti{} = state,
        _res,
        {:call, ActionMultiServer, :async_process_update_progress, [result_path, progress]}
      ) do
    ModelMulti.async_process_update_progress(state, result_path, progress)
  end

  @impl true
  def next_state(
        %ModelMulti{} = state,
        _res,
        {:call, ActionMultiServer, :async_process_resolved, [result_path, result]}
      ) do
    ModelMulti.async_process_resolved(state, result_path, result)
  end

  @impl true
  def next_state(
        %ModelMulti{} = state,
        _res,
        {:call, ActionMultiServer, :cancel, [result_path, cancel_reason]}
      ) do
    ModelMulti.cancel(state, result_path, cancel_reason)
  end

  # @impl true
  # def next_state(%Model{} = _state, _res, _) do
  #   raise "not implemented"
  # end

  @impl true
  def postcondition(
        %ModelMulti{} = prev_model,
        {:call, ActionMultiServer, :start, [result_path, payload]},
        socket
      ) do
    model = ModelMulti.start(prev_model, result_path, payload)

    assert get_real_state(socket) == model.state
  end

  @impl true
  def postcondition(
        %ModelMulti{} = prev_model,
        {:call, ActionMultiServer, :async_process_update_progress, [result_path, progress]},
        socket
      ) do
    model = ModelMulti.async_process_update_progress(prev_model, result_path, progress)

    assert get_real_state(socket) == model.state
  end

  @impl true
  def postcondition(
        %ModelMulti{} = prev_model,
        {:call, ActionMultiServer, :async_process_resolved, [result_path, result]},
        socket
      ) do
    model = ModelMulti.async_process_resolved(prev_model, result_path, result)

    assert get_real_state(socket) == model.state
  end

  @impl true
  def postcondition(
        %ModelMulti{} = prev_model,
        {:call, ActionMultiServer, :cancel, [result_path, cancel_reason]},
        socket
      ) do
    model = ModelMulti.cancel(prev_model, result_path, cancel_reason)

    assert get_real_state(socket) == model.state
  end

  defp get_real_state(socket) do
    socket
    |> Assigns.get_state()
    |> State.extract()
  end
end
