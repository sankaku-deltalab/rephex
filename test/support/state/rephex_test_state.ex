defmodule RephexTest.Fixture.State do
  alias RephexTest.Fixture.State.CounterSlice
  use Rephex.State, slices: [CounterSlice]
end
