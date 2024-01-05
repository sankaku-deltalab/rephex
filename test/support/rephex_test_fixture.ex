defmodule RephexTest.Fixture do
  alias Phoenix.LiveView.Socket

  @dialyzer {:nowarn_function, new_socket_with_slices: 0}

  def new_socket_raw() do
    %Socket{}
  end

  def new_socket_with_slices() do
    RephexTest.Fixture.State.init(%Socket{})
  end
end
