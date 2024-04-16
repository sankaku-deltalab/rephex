defmodule RephexTest.Fixture.State do
  @type t :: %{}

  @initial_state %{}

  use Rephex.State, initial_state: @initial_state
end
