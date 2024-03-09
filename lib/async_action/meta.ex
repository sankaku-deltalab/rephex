defmodule Rephex.AsyncAction.Meta do
  alias Phoenix.LiveView.Socket
  alias Rephex.AsyncAction.Base
  import Rephex.State.Assigns

  @type action_key :: {module(), Base.result_path()}

  @type t :: %{
          last_progress_updated_time: %{action_key() => pos_integer()}
        }

  @initial_state %{
    last_progress_updated_time: %{}
  }

  @meta_root :__rephex_meta_async_action

  @spec init_state(Socket.t()) :: Socket.t()
  def init_state(%Socket{} = socket) do
    socket
    |> Rephex.State.Assigns.put_state(@meta_root, @initial_state)
  end

  @spec notify_progress_updated(Socket.t(), action_key(), pos_integer()) :: Socket.t()
  def notify_progress_updated(socket, target, now) do
    socket
    |> put_state_in([@meta_root, target], now)
  end

  @spec get_last_progress_updated_time(Socket.t(), action_key()) :: pos_integer() | nil
  def get_last_progress_updated_time(socket, target) do
    get_state_in(socket, [@meta_root, target])
  end
end
