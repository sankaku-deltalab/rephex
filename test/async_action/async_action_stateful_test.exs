defmodule RephexTest.AsyncActionStatefulTest do
  use ExUnit.Case
  use RephexTest.PropCheck
  use PropCheck.StateM
  import Mox

  setup :verify_on_exit!

  alias Rephex.State.Assigns
  alias RephexTest.Fixture.AsyncActionStateful.{ActionServer, Model, State, Action, ActionMulti}

  @action_single [Action]
  @action_multi [ActionMulti]

  property "Rephex.AsyncAction stateful test" do
    forall cmds <- commands(__MODULE__) do
      {:ok, _pid} = ActionServer.start_link()
      {history, state, result} = run_commands(__MODULE__, cmds)
      ActionServer.stop()

      (result == :ok)
      |> aggregate(command_names(cmds))
      |> when_fail(
        IO.puts("""
        ---
        history:
        #{history |> Enum.map(&inspect(&1, pretty: true, width: 120)) |> Enum.map(&(&1 <> "\n---\n"))}
        ---
        state:
        #{inspect(state, pretty: true, width: 120)}
        ---
        result:
        #{inspect(result, pretty: true, width: 120)}
        ---
        """)
      )
    end
  end

  @impl true
  def initial_state() do
    Model.new()
  end

  @impl true
  def command(state) do
    running_items = Enum.to_list(state.running_items)

    running_items_multi =
      running_items
      |> Enum.filter(fn {m, _} -> m in @action_multi end)

    common_choices = [
      {12,
       {:call, ActionServer, :start_single, [gen_action(), gen_payload(), gen_start_options()]}},
      {12, {:call, ActionServer, :cancel_single, [gen_action(), gen_cancel_reason()]}},
      {12,
       {:call, ActionServer, :start_multi,
        [gen_action_multi(), gen_payload(), gen_start_options()]}},
      {6, {:call, ActionServer, :cancel_multi, [gen_action_multi(), gen_cancel_reason()]}},
      {12,
       {:call, ActionServer, :async_process_update_progress,
        [gen_random_running_item(), gen_progress()]}},
      {12, {:call, ActionServer, :consume_time, [gen_time_delta()]}}
    ]

    cancel_multi_choices =
      if running_items_multi == [] do
        []
      else
        [{6, {:call, ActionServer, :cancel_multi, [gen_action_multi(), gen_cancel_reason()]}}]
      end

    update_choices =
      if running_items == [] do
        []
      else
        gen_running_items = oneof(running_items)

        [
          {12,
           {:call, ActionServer, :async_process_update_progress,
            [gen_running_items, gen_progress()]}},
          {12,
           {:call, ActionServer, :async_process_resolved,
            [gen_running_items, gen_resolve_result()]}}
        ]
      end

    frequency(common_choices ++ update_choices ++ cancel_multi_choices)
  end

  def gen_action(), do: oneof(@action_single)

  def gen_action_multi() do
    let [m <- oneof(@action_multi), k <- gen_multi_key()] do
      {m, k}
    end
  end

  def gen_multi_key(), do: term()
  def gen_payload(), do: map(term(), term())
  def gen_progress(), do: term()

  def gen_start_options() do
    frequency([
      {12, []},
      {12, [restart_if_running: true]},
      {12, [restart_if_running: false]}
    ])
  end

  def gen_resolve_result() do
    frequency([
      {12, {:ok, term()}},
      {6, {:exit, term()}},
      {6, {:exit, gen_cancel_reason()}}
    ])
  end

  def gen_cancel_reason() do
    frequency([
      {12, {:shutdown, {:cancel, utf8()}}},
      {12, {:shutdown, {:cancel, atom()}}}
    ])
  end

  def gen_random_running_item() do
    oneof([
      gen_single_running(),
      gen_multi_running()
    ])
  end

  def gen_single_running() do
    oneof([
      {Action, [:result_single]}
    ])
  end

  def gen_multi_running() do
    let key <- gen_multi_key() do
      {ActionMulti, [:result_multi, key]}
    end
  end

  def gen_time_delta() do
    oneof(Enum.to_list(1..50))
  end

  @impl true
  def precondition(%Model{}, _) do
    true
  end

  @impl true
  def postcondition(
        %Model{} = prev_model,
        {:call, ActionServer, :start_single, [module, payload, opts]},
        socket
      ) do
    model = Model.start_single(prev_model, module, payload, opts)

    assert get_real_state(socket) == model.state
  end

  @impl true
  def postcondition(
        %Model{} = prev_model,
        {:call, ActionServer, :start_multi, [{module, key}, payload, opts]},
        socket
      ) do
    model = Model.start_multi(prev_model, {module, key}, payload, opts)

    assert get_real_state(socket) == model.state
  end

  @impl true
  def postcondition(
        %Model{} = prev_model,
        {:call, ActionServer, :async_process_update_progress, [result_path, progress]},
        socket
      ) do
    model = Model.async_process_update_progress(prev_model, result_path, progress)

    assert get_real_state(socket) == model.state
  end

  @impl true
  def postcondition(
        %Model{} = prev_model,
        {:call, ActionServer, :async_process_resolved, [result_path, result]},
        socket
      ) do
    model = Model.async_process_resolved(prev_model, result_path, result)

    assert get_real_state(socket) == model.state
  end

  @impl true
  def postcondition(
        %Model{} = prev_model,
        {:call, ActionServer, :cancel_single, [module, cancel_reason]},
        socket
      ) do
    model = Model.cancel_single(prev_model, module, cancel_reason)

    assert get_real_state(socket) == model.state
  end

  @impl true
  def postcondition(
        %Model{} = prev_model,
        {:call, ActionServer, :cancel_multi, [{module, key}, cancel_reason]},
        socket
      ) do
    model = Model.cancel_multi(prev_model, module, key, cancel_reason)

    assert get_real_state(socket) == model.state
  end

  @impl true
  def postcondition(
        %Model{},
        {:call, ActionServer, :consume_time, [_t]},
        _socket
      ) do
    true
  end

  defp get_real_state(socket) do
    socket
    |> Assigns.get_state()
    |> State.extract()
  end

  @impl true
  def next_state(
        %Model{} = state,
        _res,
        {:call, ActionServer, :start_single, [module, payload, opts]}
      ) do
    Model.start_single(state, module, payload, opts)
  end

  @impl true
  def next_state(
        %Model{} = state,
        _res,
        {:call, ActionServer, :start_multi, [{module, key}, payload, opts]}
      ) do
    Model.start_multi(state, {module, key}, payload, opts)
  end

  @impl true
  def next_state(
        %Model{} = state,
        _res,
        {:call, ActionServer, :async_process_update_progress, [{action, result_path}, progress]}
      ) do
    Model.async_process_update_progress(state, {action, result_path}, progress)
  end

  @impl true
  def next_state(
        %Model{} = state,
        _res,
        {:call, ActionServer, :async_process_resolved, [result_path, result]}
      ) do
    Model.async_process_resolved(state, result_path, result)
  end

  @impl true
  def next_state(
        %Model{} = state,
        _res,
        {:call, ActionServer, :cancel_single, [action_module, cancel_reason]}
      ) do
    Model.cancel_single(state, action_module, cancel_reason)
  end

  @impl true
  def next_state(
        %Model{} = state,
        _res,
        {:call, ActionServer, :cancel_multi, [{module, key}, cancel_reason]}
      ) do
    Model.cancel_multi(state, module, key, cancel_reason)
  end

  @impl true
  def next_state(
        %Model{} = state,
        _res,
        {:call, ActionServer, :consume_time, [t]}
      ) do
    Model.consume_time(state, t)
  end
end
