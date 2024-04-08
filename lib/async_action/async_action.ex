defmodule Rephex.AsyncAction do
  @moduledoc ~S'''
  Facilitates asynchronous operations in Phoenix LiveViews with enhanced state management.

  `Rephex.AsyncAction` seamlessly integrates with `Phoenix.LiveView` to manage asynchronous tasks,
  particularly useful for operations that require real-time feedback to the user,
  such as loading data or performing long-running tasks.

  - When executing `start/3`, if `Phoenix.LiveView.AsyncResult` is not in a loading state, it changes the specified `AsyncResult` to a loading state before calling `Phoenix.LiveView.start_async`.
  - Within the `start_async/4` function, calling the `progress` function allows for changing the loading state of `AsyncResult`.
  - If `start_async/4` returns a value, `AsyncResult.ok` is called. In the case of an exception, `AsyncResult.failed` is called.

  ## Example:

      # AsyncAction need Rephex state.
      defmodule RephexPgWeb.State do
        alias Phoenix.LiveView.AsyncResult

        @initial_state %{
          count: 0,
          double_value: AsyncResult.ok(0),
          add_twice_async: AsyncResult.ok(0)
        }

        use Rephex.State, initial_state: @initial_state

        def add_count(socket, %{amount: amount} = _payload) when is_integer(amount) do
          update_state_in(socket, [:count], &(&1 + amount))
        end
      end

      # Minimal implementation
      defmodule RephexPgWeb.State.HeavyDoubleAsync do
        use Rephex.AsyncAction, result_path: [:double_value]

        @impl true
        def initial_progress(_path, _payload) do
          # optional but recommended
          # `start/4` apply this progress synchronously.
          # AsyncResult.loading will be `{progress, _meta_values}` before start_async.
          {0, 100}
        end

        @impl true
        def start_async(_state, _path, %{amount: amount} = _payload, progress) do
          # required
          # This function will be passed to Phoenix's `start_async`.
          max = 100
          progress.({0, max})

          1..max
          |> Enum.each(fn i ->
            :timer.sleep(2)
            progress.({i, max})
          end)

          amount * 2
          # AsyncAction will call `AsyncResult.ok(prev, amount)` on `handle_async`.
        end
      end

      # Full implementation
      defmodule RephexPgWeb.State.AddCountTwiceAsync do
        alias Phoenix.LiveView
        alias RephexPgWeb.State

        @type payload :: %{amount: integer()}
        @type progress :: {current :: non_neg_integer(), total :: non_neg_integer()}
        @type cancel_reason :: any()

        use Rephex.AsyncAction,
          result_path: [:add_twice_async],
          # You can pass types for functions implemented in macro.
          payload_type: payload,
          cancel_reason_type: cancel_reason,
          progress_type: progress,
          # You can suppress hyper frequent progress updates by setting throttle.
          progress_throttle: 100

        @impl true
        def before_start(socket, _result_path, %{amount: _amount} = _payload) do
          # optional
          # This function will be called before `start_async`.
          socket |> LiveView.put_flash(:info, "Add twice start")
        end

        @impl true
        def initial_progress(_path, _payload) do
          # optional
          # This function will be called before `start_async` and determine the initial progress.
          # AsyncResult.loading will be `{progress, _meta_values}` before start_async.
          {0, 1}
        end

        @impl true
        def start_async(_state, _path, %{amount: amount} = _payload, progress) do
          # required
          # This function will be passed to Phoenix's `start_async`.
          max = 500
          progress.({0, max})

          1..max
          |> Enum.each(fn i ->
            :timer.sleep(2)
            progress.({i, max})
          end)

          amount
        end

        @impl true
        def after_resolve(socket, _result_path, result) do
          # optional
          # This function will be called after `start_async` is finished.
          case result do
            {:ok, amount} ->
              socket
              |> State.add_count(%{amount: amount})
              |> LiveView.put_flash(:info, "Add twice done: #{amount}")

            {:exit, _reason} ->
              socket
              |> LiveView.put_flash(:error, "Add twice failed")
          end
        end

        @impl true
        def generate_failed_value(_result_path, exit_reason) do
          # optional
          # You can customize the failed value.
          case exit_reason do
            {:shutdown, :cancel} -> "canceled by no-reason"
            {:shutdown, {:cancel, text}} when is_bitstring(text) -> "canceled by #{text}"
            _ -> "unknown reason"
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
        def handle_event("start_heavy_double", %{"amount" => amount}, socket) do
          {am, _} = Integer.parse(amount)

          {:noreply, socket |> State.HeavyDoubleAsync.start(%{amount: am})}
        end

        @impl true
        def handle_event("cancel_heavy_double", _params, socket) do
          {:noreply, socket |> State.HeavyDoubleAsync.cancel()}
        end

        @impl true
        def handle_event(
              "start_add_count_twice",
              %{"force" => force, "amount" => amount},
              socket
            )
            when force in ["1", "0"] do
          {am, _} = Integer.parse(amount)

          {:noreply,
          socket
          |> State.AddCountTwiceAsync.start(%{amount: am}, restart_if_running: force == "1")}
        end

        @impl true
        def handle_event("cancel_add_count_twice", _params, socket) do
          {:noreply, socket |> State.AddCountTwiceAsync.cancel({:shutdown, {:cancel, "user cancel"}})}
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

        def start_heavy_double_button(assigns) do
          ~H"""
          <button class="border-2" phx-click="start_heavy_double" phx-value-amount={@amount}>
            <%= @text %>
          </button>
          """
        end

        def start_add_twice_button(assigns) do
          ~H"""
          <button
            class="border-2"
            phx-click="start_add_count_twice"
            phx-value-amount={@amount}
            phx-value-force={@force}
          >
            <%= @text %>
          </button>
          """
        end

        @impl true
        def render(assigns) do
          ~H"""
          <div class="border-2 m-5">
            <div class="underline">Minimal AsyncAction Example</div>
            <div>Double the amount with a delay. Async state is in AsyncResult.</div>
            <%= case @rpx.double_value do %>
              <% %AsyncResult{loading: {{current, max}, _meta}} -> %>
                <%= "#{current} / #{max}" %>
              <% %AsyncResult{failed: reason} when reason != nil -> %>
                <div>Failed: <%= reason %></div>
                <.start_heavy_double_button amount="2" force="0" text="Calculate double of 2" />
              <% %AsyncResult{ok?: true, result: result} -> %>
                Double of amount: <%= result %>
                <.start_heavy_double_button amount="2" force="0" text="Calculate double of 2" />
            <% end %>
          </div>

          <div>Count: <%= @rpx.count %></div>

          <div class="border-2 m-5">
            <div class="underline">Full-implemented AsyncAction Example</div>
            <div>We can manipulate values not in AsyncResult.</div>
            <%= case @rpx.add_twice_async do %>
              <% %AsyncResult{loading: {{current, max}, _meta}} -> %>
                <button class="border-2" phx-click="cancel_add_count_twice">
                  Cancel
                </button>
                <.start_add_twice_button amount="2" force="0" text="Start without option" />
                <.start_add_twice_button amount="2" force="1" text="Force restart" />
                <%= "#{current} / #{max}" %>
              <% %AsyncResult{failed: reason} when reason != nil -> %>
                <.start_add_twice_button amount="2" force="0" text="Async add 2" />
                <div>Failed: <%= reason %></div>
              <% _ -> %>
                <.start_add_twice_button amount="2" force="0" text="Async add 2" />
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

    result_path = Keyword.fetch!(opt, :result_path)
    payload_type = Keyword.get(opt, :payload_type, default_payload_type)
    cancel_reason_type = Keyword.get(opt, :cancel_reason_type, default_cancel_reason_type)
    _progress_type = Keyword.get(opt, :progress_type, default_progress_type)

    progress_throttle = Keyword.get(opt, :progress_throttle, 0)

    quote do
      @behaviour Rephex.AsyncAction.Base
      @type result_path :: Backend.result_path()

      @type option :: {:restart_if_running, boolean()}

      @doc """
      Start an asynchronous action.

      - If `Phoenix.LiveView.AsyncResult` is not in a loading state, it changes the specified `AsyncResult` to a loading state before calling `Phoenix.LiveView.start_async`.
      - Within the `start_async/4` function, calling the `progress` function allows for changing the loading state of `AsyncResult`.
      - If `start_async/4` returns a value, `AsyncResult.ok` is called. In the case of an exception, `AsyncResult.failed` is called.
      """
      @spec start(Socket.t(), unquote(payload_type)) :: Socket.t()
      @spec start(Socket.t(), unquote(payload_type), [option()]) :: Socket.t()
      def start(%Socket{} = socket, payload, opts \\ []) do
        Backend.start(socket, {__MODULE__, unquote(result_path)}, payload, opts)
      end

      @doc """
      Cancel an asynchronous action.

      - `AsyncResult.failed` will be called.
      - `generate_failed_value/2` will be called.
      - `after_resolve/3` will be called.
      """
      @spec cancel(Socket.t()) :: Socket.t()
      @spec cancel(Socket.t(), unquote(cancel_reason_type)) :: Socket.t()
      def cancel(%Socket{} = socket, reason \\ {:shutdown, :cancel}) do
        Backend.cancel(socket, {__MODULE__, unquote(result_path)}, reason)
      end

      @impl true
      def options() do
        %{throttle: unquote(progress_throttle)}
      end
    end
  end
end
