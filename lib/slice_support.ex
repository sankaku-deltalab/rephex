defmodule Rephex.Slice.Support do
  alias Phoenix.LiveView.AsyncResult
  alias Phoenix.LiveView.Socket

  def start_async(%Socket{} = socket, module, payload, get_slice: get_slice)
      when is_atom(module) and is_function(get_slice, 1) do
    if Rephex.State.Support.propagated?(socket),
      do: raise("Must start async on propagated state.")

    slice_state = get_slice.(socket)
    liveview_pid = self()
    send_msg = fn msg -> send(liveview_pid, {Rephex.AsyncAction, module, msg}) end
    fun_raw = &module.start_async/3
    fun_for_async = fn -> fun_raw.(slice_state, payload, send_msg) end

    case module.before_async(socket, payload) do
      {:continue, %Socket{} = socket} ->
        Phoenix.LiveView.start_async(socket, module, fun_for_async)

      {:abort, %Socket{} = socket} ->
        socket
    end
  end

  def cancel_async(%Socket{} = socket, module, reason \\ {:shutdown, :cancel})
      when is_atom(module) do
    if Rephex.State.Support.propagated?(socket),
      do: raise("Must cancel async on propagated state.")

    Phoenix.LiveView.cancel_async(socket, module, reason)
  end

  def reset_async!(slice_state, key, opt) do
    case opt do
      [ok: result] ->
        %{slice_state | key => AsyncResult.ok(result)}

      [failed: reason] when reason != nil ->
        %{slice_state | key => AsyncResult.failed(slice_state[key], reason)}

      [loading: loading_state] when loading_state != nil ->
        %{slice_state | key => AsyncResult.loading(loading_state)}
    end
  end

  def update_async!(slice_state, key, opt) do
    case opt do
      [ok: result] ->
        %{slice_state | key => AsyncResult.ok(slice_state[key], result)}

      [failed: reason] when reason != nil ->
        %{slice_state | key => AsyncResult.failed(slice_state[key], reason)}

      [loading: loading_state] when loading_state != nil ->
        %{slice_state | key => AsyncResult.loading(slice_state[key], loading_state)}
    end
  end

  def update_async_loading_state!(slice_state, key, loading_state \\ true) do
    new_async =
      case slice_state[key] do
        %AsyncResult{loading: nil} = async -> async
        _ = async -> AsyncResult.loading(async, loading_state)
      end

    %{slice_state | key => new_async}
  end

  defmacro __using__([slice: slice_module] = _opt) do
    quote do
      @root Rephex.root()
      @slice_module unquote(slice_module)

      @type slice_module :: unquote(slice_module)
      @type state :: map()
      @type async_module :: module()

      @doc """
      Initialize Rephex slice.

      ## Example

      ```ex
      defmodule SliceA do
        ...

        @impl true
        @spec init(Socket.t()) :: Socket.t()
        def init(%Socket{} = socket) do
          Support.init_slice(socket, %State{})
        end
      end
      ```
      """
      @spec init_slice(Socket.t(), state()) :: Socket.t()
      def init_slice(%Socket{} = socket, %{} = initial_state) do
        Rephex.State.Support.put_slice!(socket, @slice_module, initial_state)
      end

      @doc """
      Update Rephex slice.

      ## Example

      ```ex
      def add_count(%Socket{} = socket, %{amount: am}) do
        update_slice(socket, fn state ->
          %{state | count: state.count + am}
        end)
      end
      ```
      """
      @spec update_slice(Socket.t(), (state() -> state())) :: Socket.t()
      def update_slice(%Socket{} = socket, func) do
        Rephex.State.Support.update_slice!(socket, @slice_module, func)
      end

      @doc """
      Get Rephex slice from socket.
      """
      @spec get_slice(Socket.t()) :: state()
      def get_slice(%Socket{} = socket) do
        Rephex.State.Support.get_slice!(socket, @slice_module)
      end

      @doc """
      Get Rephex root state from socket.
      """
      @spec get_root(Socket.t()) :: Rephex.State.t()
      def get_root(%Socket{} = socket) do
        socket.assigns[@root]
      end

      @doc """
      Start async action.

      ## Example

      ```ex
      defmodule RephexUser.AddCountAsync do
        ...
      end

      def add_count_async(%Socket{} = socket, %{amount: _} = payload) do
        socket
        |> Support.start_async(AddCountAsync, payload)
      end
      ```
      """
      @spec start_async(Socket.t(), async_module(), map()) :: Socket.t()
      def start_async(%Socket{} = socket, module, payload) when is_atom(module) do
        Rephex.Slice.Support.start_async(socket, module, payload, get_slice: &get_slice/1)
      end

      @doc """
      Cancel async action.
      """
      @spec cancel_async(Socket.t(), async_module(), any()) :: Socket.t()
      def cancel_async(%Socket{} = socket, module, reason \\ {:shutdown, :cancel})
          when is_atom(module) do
        Rephex.Slice.Support.cancel_async(socket, module, reason)
      end

      @doc """
      Reset AsyncResult in state.

      ## Example

      ```ex
      # %State{video: %AsyncResult{}}
      socket
      |> Support.reset_async!(:video, ok: video_content)
      |> Support.reset_async!(:video, failed: :video_not_found)
      |> Support.reset_async!(:video, loading: %{progress: {0, 100}}})
      |> Support.reset_async!(:video, loading: true})  # no progress
      ```
      """
      def reset_async!(%Socket{} = socket, key, opt) do
        update_slice(socket, fn state ->
          Rephex.Slice.Support.reset_async!(state, key, opt)
        end)
      end

      @doc """
      Update AsyncResult in state.

      ## Example

      ```ex
      # %State{video: %AsyncResult{}}
      socket
      |> Support.update_async!(:video, ok: video_content)
      |> Support.update_async!(:video, failed: :video_not_found)
      |> Support.update_async!(:video, loading: %{progress: {0, 100}}})
      |> Support.update_async!(:video, loading: true})  # no progress
      ```
      """
      def update_async!(%Socket{} = socket, key, opt) do
        update_slice(socket, fn state ->
          Rephex.Slice.Support.update_async!(state, key, opt)
        end)
      end

      @doc """
      Update AsyncResult loading state.
      If AsyncResult is not loading, it will do nothing.

      ## Example

      ```ex
      def update_video_loading_progress(%Socket{} = socket, {_current, _max} = payload) do
        # %State{video: %AsyncResult{}}

        socket
        |> Support.update_async_loading_state!(:video, payload)
      end
      ```
      """
      @spec update_async_loading_state!(Socket.t(), atom(), any()) :: Socket.t()
      def update_async_loading_state!(%Socket{} = socket, key, loading_state \\ true) do
        update_slice(socket, fn state ->
          Rephex.Slice.Support.update_async_loading_state!(state, key, loading_state)
        end)
      end
    end
  end
end
