defmodule Rephex.Slice do
  @callback slice_info() :: %{initial_state: map(), async_modules: [atom()]}
end
