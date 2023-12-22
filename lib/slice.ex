defmodule Rephex.Slice do
  @callback slice_info() :: %{name: atom(), initial_state: map(), async_modules: [atom()]}
end
