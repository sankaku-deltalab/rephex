defmodule Rephex.AsyncActionMulti do
  @moduledoc """
  TODO: write module documentation
  """
  alias Phoenix.LiveView.Socket
  alias Rephex.AsyncAction.Backend

  defmacro __using__(opt) do
    default_payload_type =
      quote do
        map()
      end

    default_cancel_reason_type =
      quote do
        any()
      end

    default_progress_type =
      quote do
        any()
      end

    default_key_type =
      quote do
        term()
      end

    result_map_path = Keyword.fetch!(opt, :result_map_path)
    payload_type = Keyword.get(opt, :payload_type, default_payload_type)
    cancel_reason_type = Keyword.get(opt, :cancel_reason_type, default_cancel_reason_type)
    _progress_type = Keyword.get(opt, :progress_type, default_progress_type)
    key_type = Keyword.get(opt, :key_type, default_key_type)

    progress_throttle = Keyword.get(opt, :progress_throttle, 0)

    quote do
      @behaviour Rephex.AsyncAction.Base
      @type result_path :: Backend.result_path()

      @type option :: {:restart_if_running, boolean()}
      @spec start(Socket.t(), unquote(key_type), unquote(payload_type)) :: Socket.t()
      @spec start(Socket.t(), unquote(key_type), unquote(payload_type), [option()]) :: Socket.t()
      def start(%Socket{} = socket, key, payload, opts \\ []) do
        result_path = unquote(result_map_path) ++ [key]

        socket
        |> Backend.start({__MODULE__, result_path}, payload, opts)
      end

      @spec cancel(Socket.t(), unquote(key_type)) :: Socket.t()
      @spec cancel(Socket.t(), unquote(key_type), unquote(cancel_reason_type)) :: Socket.t()
      def cancel(%Socket{} = socket, key, reason \\ {:shutdown, :cancel}) do
        result_path = unquote(result_map_path) ++ [key]
        Backend.cancel(socket, {__MODULE__, result_path}, reason)
      end

      @impl true
      def options() do
        %{throttle: unquote(progress_throttle)}
      end
    end
  end
end
