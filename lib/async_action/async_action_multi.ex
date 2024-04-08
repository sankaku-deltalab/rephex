defmodule Rephex.AsyncActionMulti do
  @moduledoc ~S'''
  Manages multiple asynchronous operations under a specified map in Phoenix LiveViews,
  extending `Rephex.AsyncAction` capabilities.

  `Rephex.AsyncGroupAction` builds upon the foundation of `Rephex.AsyncAction`
  by introducing the management of multiple `AsyncResult` instances within a single, specified map.

  This module is designed for scenarios where concurrent asynchronous tasks need to be
  executed and monitored within the same LiveView component,
  offering granular control over each task's lifecycle and state.

  ## Example:

      # AsyncAction need Rephex state.
      defmodule RephexPgWeb.State do
        alias Phoenix.LiveView.AsyncResult

        @initial_state %{
          count: 0,
          # AsyncActionMulti requires map will contain AsyncResult.
          delayed_add_multi: %{}
        }

        use Rephex.State, initial_state: @initial_state

        def add_count(socket, %{amount: amount} = _payload) when is_integer(amount) do
          update_state_in(socket, [:count], &(&1 + amount))
        end
      end

      # Minimal implementation
      defmodule RephexPgWeb.State.DelayedAddAsync do
        alias RephexPgWeb.State

        use Rephex.AsyncActionMulti, result_map_path: [:delayed_add_multi]

        @impl true
        def start_async(_state, _path, %{amount: amount} = _payload, _progress) do
          :timer.sleep(1000)
          amount
        end

        @impl true
        def after_resolve(socket, _result_path, result) do
          case result do
            {:ok, amount} ->
              socket
              |> State.add_count(%{amount: amount})

            {:exit, _reason} ->
              socket
          end
        end
      end

      # Usage in LiveView
      defmodule RephexPgWeb.AccountLive.Index do
        alias RephexPgWeb.State
        use RephexPgWeb, :live_view
        use Rephex.LiveView

        alias Phoenix.LiveView.AsyncResult

        @impl true
        def mount(_params, _session, socket) do
          {:ok, socket |> State.init()}
        end

        @impl true
        def handle_event(
              "start_delayed_add",
              %{"multi_key" => key, "amount" => amount},
              socket
            ) do
          {am, _} = Integer.parse(amount)
          {:noreply, socket |> State.DelayedAddAsync.start(key, %{amount: am})}
        end

        def start_delayed_add_button(assigns) do
          ~H"""
          <button
            class="border-2"
            phx-click="start_delayed_add"
            phx-value-amount={@amount}
            phx-value-multi_key={@multi_key}
          >
            <%= @text %>
          </button>
          """
        end

        @impl true
        def render(assigns) do
          ~H"""
          <div class="border-2 m-5">
            <div class="underline">AsyncActionMulti Example</div>
            <div>We can run multiple async actions with the same module.</div>
            <%= for i <- 1..3 do %>
              <%= ~s{(AsyncResult is at [:delayed_add_multi, "key-#{i}"])} %>
              <.start_delayed_add_button
                amount={i}
                multi_key={"key-#{i}"}
                text={"Start delayed add #{i} by key-#{i}"}
              />
            <% end %>
          </div>
          """
        end
      end

  '''
  alias Phoenix.LiveView.Socket
  alias Rephex.AsyncAction.Backend

  defmacro __using__(opt) do
    default_payload_type =
      quote do
        map()
      end

    default_cancel_reason_type =
      quote do
        any()
      end

    default_progress_type =
      quote do
        any()
      end

    default_key_type =
      quote do
        term()
      end

    result_map_path = Keyword.fetch!(opt, :result_map_path)
    payload_type = Keyword.get(opt, :payload_type, default_payload_type)
    cancel_reason_type = Keyword.get(opt, :cancel_reason_type, default_cancel_reason_type)
    _progress_type = Keyword.get(opt, :progress_type, default_progress_type)
    key_type = Keyword.get(opt, :key_type, default_key_type)

    progress_throttle = Keyword.get(opt, :progress_throttle, 0)

    quote do
      @behaviour Rephex.AsyncAction.Base
      @type result_path :: Backend.result_path()

      @type option :: {:restart_if_running, boolean()}

      @doc """
      Start an asynchronous action.

      - Create `Phoenix.LiveView.AsyncResult` to `result_map_path ++ [key]`.
      - If `Phoenix.LiveView.AsyncResult` is not in a loading state, it changes the specified `AsyncResult` to a loading state before calling `Phoenix.LiveView.start_async`.
      - Within the `start_async/4` function, calling the `progress` function allows for changing the loading state of `AsyncResult`.
      - If `start_async/4` returns a value, `AsyncResult.ok` is called. In the case of an exception, `AsyncResult.failed` is called.
      """
      @spec start(Socket.t(), unquote(key_type), unquote(payload_type)) :: Socket.t()
      @spec start(Socket.t(), unquote(key_type), unquote(payload_type), [option()]) :: Socket.t()
      def start(%Socket{} = socket, key, payload, opts \\ []) do
        result_path = unquote(result_map_path) ++ [key]

        socket
        |> Backend.start({__MODULE__, result_path}, payload, opts)
      end

      @doc """
      Cancel an asynchronous action.

      - `AsyncResult.failed` will be called.
      - `generate_failed_value/2` will be called.
      - `after_resolve/3` will be called.
      """
      @spec cancel(Socket.t(), unquote(key_type)) :: Socket.t()
      @spec cancel(Socket.t(), unquote(key_type), unquote(cancel_reason_type)) :: Socket.t()
      def cancel(%Socket{} = socket, key, reason \\ {:shutdown, :cancel}) do
        result_path = unquote(result_map_path) ++ [key]
        Backend.cancel(socket, {__MODULE__, result_path}, reason)
      end

      @impl true
      def options() do
        %{throttle: unquote(progress_throttle)}
      end
    end
  end
end
