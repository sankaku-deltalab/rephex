defmodule Rephex.Slice.Support do
  import Phoenix.Component
  import Phoenix.LiveComponent
  alias Phoenix.LiveView.Socket

  defmacro __using__([struct: slice_struct, name: slice_name] = _opt) do
    quote do
      @root Rephex.root()
      @type state :: unquote(slice_struct).t()
      @slice_name unquote(slice_name)
      @type slice_name :: unquote(slice_name)
      @slice_struct unquote(slice_struct)

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
      def init_slice(%Socket{} = socket, %slice_struct{} = initial_state) do
        socket
        |> update(@root, fn root -> Map.put(root, @slice_name, initial_state) end)
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
        new_slice = socket |> get_slice() |> func.()

        socket
        |> update(@root, &%{&1 | @slice_name => new_slice})
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
      def start(%Socket{} = socket, %{amount: am}) do
        Support.start_async(socket, __MODULE__, fn _state ->
          :timer.sleep(1000)
          am
        end)
      end
      ```
      """
      @spec start_async(Socket.t(), module(), (state() -> any())) :: Socket.t()
      def start_async(%Socket{} = socket, module, fun)
          when is_atom(module) and is_function(fun, 1) do
        fun_for_async = fn -> fun.(get_slice(socket)) end

        Phoenix.LiveView.start_async(socket, module, fun_for_async)
      end
    end
  end
end
