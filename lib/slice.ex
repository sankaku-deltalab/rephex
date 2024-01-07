defmodule Rephex.Slice do
  alias Phoenix.LiveView.{Socket, AsyncResult}

  @type slice_module :: module()

  @callback slice_info() :: %{initial_state: map(), async_modules: [atom()]}

  def get_async_module_to_slice_map(slice_modules) do
    slice_modules
    |> Enum.flat_map(fn slice_module ->
      %{async_modules: async_modules} = slice_module.slice_info()

      Enum.map(async_modules, fn async_module -> {async_module, slice_module} end)
    end)
    |> Map.new()
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

  def parent_module(module) when is_atom(module) do
    module
    |> Module.split()
    |> Enum.drop(-1)
    |> Module.concat()
  end

  defmacro __using__(opt) do
    async_modules = Keyword.get(opt, :async_modules, [])
    initial_state = Keyword.get(opt, :initial_state, %{})

    quote do
      @behaviour Rephex.Slice

      @impl true
      def slice_info(),
        do: %{
          initial_state: unquote(initial_state),
          async_modules: unquote(async_modules)
        }

      defmodule Support do
        # slice is parent of Support
        @slice_module Rephex.Slice.parent_module(__MODULE__)

        @root Rephex.root()

        @type slice_module :: Rephex.Slice.parent_module(__MODULE__)
        @type state :: map()
        @type async_module :: module()

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
        def update_slice(%Socket{} = socket, fun) do
          Rephex.State.Support.update_slice!(socket, @slice_module, fun)
        end

        @doc """
        Update Rephex slice by `update_in/3`.

        ## Example

        ```ex
        def add_count(%Socket{} = socket, %{amount: am}) do
          update_slice_in(socket, [:count], &(&1 + am))
        end
        ```
        """
        @spec update_slice_in(Socket.t(), [any()], (any() -> any())) :: Socket.t()
        def update_slice_in(%Socket{} = socket, keys, fun) when is_function(fun, 1) do
          Rephex.State.Support.update_slice!(socket, @slice_module, &update_in(&1, keys, fun))
        end

        @doc """
        Get Rephex slice from socket.
        """
        @spec get_slice(Socket.t()) :: state()
        def get_slice(%Socket{} = socket) do
          Rephex.State.Support.get_slice!(socket, @slice_module)
        end

        @doc """
        Get Rephex slice element by `get_in/2`.

        ## Example

        ```ex
        def get_count(%Socket{} = socket) do
          get_slice_in(socket, [:count])
        end
        ```
        """
        @spec get_slice_in(Socket.t(), [any()]) :: any()
        def get_slice_in(%Socket{} = socket, keys) do
          socket
          |> get_slice()
          |> get_in(keys)
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
        @spec reset_async!(
                Socket.t(),
                atom(),
                [ok: any()] | [failed: any()] | [loading: any()]
              ) :: Socket.t()
        def reset_async!(%Socket{} = socket, key, ok: result),
          do: _reset_async!(socket, key, ok: result)

        def reset_async!(%Socket{} = socket, key, failed: reason),
          do: _reset_async!(socket, key, failed: reason)

        def reset_async!(%Socket{} = socket, key, loading: loading_state),
          do: _reset_async!(socket, key, loading: loading_state)

        defp _reset_async!(%Socket{} = socket, key, opt) do
          update_slice(socket, fn state ->
            Rephex.Slice.reset_async!(state, key, opt)
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
        @spec update_async!(
                Socket.t(),
                atom(),
                [ok: any()] | [failed: any()] | [loading: any()]
              ) :: Socket.t()
        def update_async!(%Socket{} = socket, key, ok: result),
          do: _update_async!(socket, key, ok: result)

        def update_async!(%Socket{} = socket, key, failed: reason),
          do: _update_async!(socket, key, failed: reason)

        def update_async!(%Socket{} = socket, key, loading: loading_state),
          do: _update_async!(socket, key, loading: loading_state)

        defp _update_async!(%Socket{} = socket, key, opt) do
          update_slice(socket, fn state ->
            Rephex.Slice.update_async!(state, key, opt)
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
            Rephex.Slice.update_async_loading_state!(state, key, loading_state)
          end)
        end
      end
    end
  end
end
