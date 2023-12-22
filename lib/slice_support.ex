defmodule Rephex.Slice.Support do
  alias Phoenix.LiveView.AsyncResult
  alias Phoenix.LiveView.Socket

  defmacro __using__([name: slice_name] = _opt) do
    quote do
      @root Rephex.root()
      @slice_name unquote(slice_name)

      @type slice_name :: unquote(slice_name)
      @type state :: map()

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
        Rephex.State.Support.put_slice(socket, @slice_name, initial_state)
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
        Rephex.State.Support.update_slice(socket, @slice_name, func)
      end

      @doc """
      Get Rephex slice from socket.
      """
      @spec get_slice(Socket.t()) :: state()
      def get_slice(%Socket{} = socket) do
        Rephex.State.Support.get_slice(socket, @slice_name)
      end

      @doc """
      Get Rephex slice from root state.

      ## Example

      ```ex
      def count(root) do
        root
        |> Support.slice_in_root()
        |> then(fn %State{count: c} -> c end)
      end
      ```
      """
      @spec slice_in_root(%{slice_name() => state}) :: state()
      def slice_in_root(%{@slice_name => state}) do
        state
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
        |> LiveView.put_flash(:info, "Start async action")
      end
      ```
      """
      @spec start_async(Socket.t(), module(), map()) :: Socket.t()
      def start_async(%Socket{} = socket, module, payload) when is_atom(module) do
        fun_raw = &module.start_async/2
        fun_for_async = fn -> fun_raw.(get_slice(socket), payload) end

        Phoenix.LiveView.start_async(socket, module, fun_for_async)
      end

      @doc """
      Set AsyncResult as loading.

      ## Example

      ```ex
      def load_video(%Socket{} = socket, _payload) do
        # %State{video: %AsyncResult{}}

        socket
        |> Support.set_async_as_loading!(:video)
        |> load_video_async()
      end
      ```
      """
      @spec set_async_as_loading!(Socket.t(), atom()) :: Socket.t()
      def set_async_as_loading!(%Socket{} = socket, key) do
        update_slice(socket, fn state ->
          %{state | key => AsyncResult.loading(state[key])}
        end)
      end

      @doc """
      Set AsyncResult as ok.
      """
      @spec set_async_as_ok!(Socket.t(), atom(), any()) :: Socket.t()
      def set_async_as_ok!(%Socket{} = socket, key, result) do
        update_slice(socket, fn state ->
          %{state | key => AsyncResult.ok(state[key], result)}
        end)
      end

      @doc """
      Set AsyncResult as failed.
      """
      @spec set_async_as_failed!(Socket.t(), atom(), any()) :: Socket.t()
      def set_async_as_failed!(%Socket{} = socket, key, reason) do
        update_slice(socket, fn state ->
          %{state | key => AsyncResult.failed(state[key], reason)}
        end)
      end
    end
  end
end
