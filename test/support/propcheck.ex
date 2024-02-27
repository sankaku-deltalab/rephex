defmodule RephexTest.PropCheck do
  @doc """
  Stub for PropCheck.Properties.property/2
  """
  def property(_, _, _ \\ nil, _ \\ nil) do
  end

  defmacro __using__(opts) do
    if System.get_env("RUNNING_IN_ELIXIR_LS") == nil do
      quote do
        use PropCheck, unquote(opts)
      end
    else
      quote do
        # Copied from PropCheck.__using__/1
        # PropCheck.Properties.property/2 crash the Elixir Language Server

        import PropCheck
        import PropCheck.Properties, except: [property: 1, property: 2, property: 3, property: 4]
        # import :proper_types, except: [lazy: 1, to_binary: 1, function: 2]
        import PropCheck.BasicTypes
        import PropCheck.TargetedPBT

        import Els.PropCheck
      end
    end
  end
end
