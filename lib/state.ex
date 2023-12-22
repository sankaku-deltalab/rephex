defmodule Rephex.State do
  @type t :: %__MODULE__{
          root?: boolean(),
          slices: %{atom() => struct()}
        }

  defstruct root?: true, slices: %{}

  defmacro __using__([slices: slices] = _opt) when is_list(slices) do
    quote do
      alias Rephex.State.Support
      alias Phoenix.LiveView.Socket

      @__slices unquote(slices)
      @__async_modules Support.collect_async_modules(@__slices)

      @spec init(Socket.t()) :: Socket.t()
      def init(%Socket{} = socket) do
        Support.init_state(socket, @__slices)
      end

      def resolve_async(%Socket{} = socket, name, result) do
        Support.resolve_async(socket, @__async_modules, name, result)
      end
    end
  end

  @spec propagate(t()) :: t()
  def propagate(%__MODULE__{} = rephex_state), do: %{rephex_state | root?: false}
end

defmodule Rephex.State.Support do
  alias Phoenix.LiveView.Socket

  @root Rephex.root()

  @empty_root %Rephex.State{}

  @spec init_state(Socket.t(), [module()]) :: Socket.t()
  def init_state(%Socket{} = socket, slice_modules) do
    socket =
      socket
      |> Phoenix.Component.assign_new(@root, fn -> @empty_root end)

    slice_modules
    |> Enum.reduce(socket, fn module, socket -> module.init(socket) end)
  end

  @spec collect_async_modules([module()]) :: MapSet.t()
  def collect_async_modules(slice_modules) do
    slice_modules
    |> Enum.flat_map(& &1.async_modules())
    |> MapSet.new()
  end

  @spec resolve_async(Socket.t(), MapSet.t(), atom(), any()) :: any()
  def resolve_async(%Socket{} = socket, %MapSet{} = async_modules, name, result) do
    if name in async_modules do
      name.resolve(socket, result)
    else
      raise {:not_async_module, name}
    end
  end

  @spec get_slice(Socket.t(), atom()) :: map()
  def get_slice(%Socket{} = socket, slice_name) when is_atom(slice_name) do
    socket.assigns[@root][slice_name]
  end
end
