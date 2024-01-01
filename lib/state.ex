defmodule Rephex.State do
  alias Rephex.State.Support
  alias Phoenix.LiveView.Socket

  @type t :: %__MODULE__{
          root?: boolean(),
          slices: %{atom() => map()}
        }

  defstruct root?: true, slices: %{}

  defmacro __using__([slices: slices] = _opt) when is_list(slices) do
    quote do
      @__slices unquote(slices)

      @spec init(Socket.t()) :: Socket.t()
      def init(%Socket{} = socket) do
        Support.init_state(socket, @__slices)
      end

      @spec slice_modules() :: [module()]
      def slice_modules(), do: @__slices
    end
  end

  @type slice_state :: map()

  @spec propagate(t()) :: t()
  def propagate(%__MODULE__{} = rephex_state), do: %{rephex_state | root?: false}

  @spec get_slice!(t(), module()) :: slice_state()
  def get_slice!(%__MODULE__{slices: slices} = _, slice_module) when is_atom(slice_module) do
    slices[slice_module]
  end

  @spec put_slice!(t(), module(), slice_state()) :: t()
  def put_slice!(%__MODULE__{root?: root?, slices: slices} = root, slice_module, slice_state)
      when is_atom(slice_module) do
    if not root?, do: raise("Must not mutate propagated state.")

    slices = Map.put(slices, slice_module, slice_state)
    %Rephex.State{root | slices: slices}
  end

  @spec update_slice!(t(), module(), (slice_state() -> slice_state())) :: t()
  def update_slice!(%__MODULE__{root?: root?, slices: slices} = root, slice_module, fun)
      when is_atom(slice_module) and is_function(fun, 1) do
    if not root?, do: raise("Must not mutate propagated state.")

    slices = Map.update!(slices, slice_module, fun)
    %Rephex.State{root | slices: slices}
  end
end

defmodule Rephex.State.Support do
  @moduledoc """
  Contain in-socket Rephex.State functions.
  """
  alias Phoenix.LiveView.Socket

  @root Rephex.root()

  @type slice_state :: map()
  @type slice_module :: module()
  @type async_module :: module()

  @spec init_state(Socket.t(), [slice_module()]) :: Socket.t()
  def init_state(%Socket{} = socket, slice_modules) do
    slices =
      slice_modules
      |> Enum.map(fn module ->
        %{initial_state: initial_state} = module.slice_info()
        {module, initial_state}
      end)
      |> Map.new()

    socket
    |> Phoenix.Component.assign(@root, %Rephex.State{root?: true, slices: slices})
  end

  @spec get_async_module_to_slice_map([module()]) :: %{module() => module()}
  def get_async_module_to_slice_map(slice_modules) do
    slice_modules
    |> Enum.flat_map(fn slice_module ->
      %{async_modules: async_modules} = slice_module.slice_info()
      Enum.map(async_modules, fn async_module -> {async_module, slice_module} end)
    end)
    |> Map.new()
  end

  @spec get_slice!(Socket.t(), atom()) :: map()
  def get_slice!(%Socket{} = socket, slice_module) when is_atom(slice_module) do
    Rephex.State.get_slice!(socket.assigns[@root], slice_module)
  end

  @spec put_slice!(Socket.t(), atom(), slice_state()) :: Socket.t()
  def put_slice!(%Socket{} = socket, slice_module, %{} = slice_state)
      when is_atom(slice_module) do
    Phoenix.Component.update(
      socket,
      @root,
      &Rephex.State.put_slice!(&1, slice_module, slice_state)
    )
  end

  @spec update_slice!(Socket.t(), atom(), (slice_state() -> slice_state())) :: map()
  def update_slice!(%Socket{} = socket, slice_module, fun)
      when is_atom(slice_module) and is_function(fun, 1) do
    Phoenix.Component.update(
      socket,
      @root,
      &Rephex.State.update_slice!(&1, slice_module, fun)
    )
  end

  @spec propagated?(Socket.t()) :: boolean()
  def propagated?(%Socket{} = socket), do: not socket.assigns[@root].root?
end
