defmodule Rephex.Util do
  @doc """
  ```ex
  defmodule BehaviourA do
    @callback foo(any(), any()) :: any()

    @optional_callbacks foo: 2
  end

  defmodule BehaviourAImpl do
    @behaviour BehaviourA
  end

  defmodule User do
    def call_foo() do
      {:ok, :but_not_impl} =
        Rephex.Util.call_optional(
          {BehaviourAImpl, :foo, 2},
          [1, 2],
          {:ok, :but_not_impl}
        )
    end
  end
  ```
  """
  @spec call_optional(mfa :: mfa(), args :: list(), default :: any()) :: any()
  def call_optional({module, fun_name, arity} = _mfa, args, default)
      when is_atom(module) and
             is_atom(fun_name) and
             is_integer(arity) and
             is_list(args) and
             length(args) == arity do
    cond do
      function_exported?(module, fun_name, arity) -> apply(module, fun_name, args)
      true -> default
    end
  end
end
