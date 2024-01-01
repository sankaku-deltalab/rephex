defmodule Rephex.Slice do
  @callback slice_info() :: %{initial_state: map(), async_modules: [atom()]}

  defmacro __using__(opt) do
    async_modules = Keyword.get(opt, :async_modules, [])
    initial_state = Keyword.get(opt, :initial_state, %{})

    quote do
      @behaviour Rephex.Slice

      defmodule Support do
        # slice is parent of Support
        use Rephex.Slice.Support, slice: Module.concat(Enum.drop(Module.split(__MODULE__), -1))
      end

      @impl true
      def slice_info(),
        do: %{
          initial_state: unquote(initial_state),
          async_modules: unquote(async_modules)
        }
    end
  end
end
