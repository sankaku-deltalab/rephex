defmodule Rephex.AsyncAction do
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

    result_path = Keyword.fetch!(opt, :result_path)
    payload_type = Keyword.get(opt, :payload_type, default_payload_type)
    cancel_reason_type = Keyword.get(opt, :cancel_reason_type, default_cancel_reason_type)
    _progress_type = Keyword.get(opt, :progress_type, default_progress_type)

    quote do
      @behaviour Rephex.AsyncAction.Base
      @type result_path :: Backend.result_path()

      @spec start(Socket.t(), unquote(payload_type)) :: Socket.t()
      def start(%Socket{} = socket, payload) do
        Backend.start(socket, __MODULE__, unquote(result_path), payload)
      end

      @spec cancel(Socket.t()) :: Socket.t()
      @spec cancel(Socket.t(), unquote(cancel_reason_type)) :: Socket.t()
      def cancel(%Socket{} = socket, reason \\ {:shutdown, :cancel}) do
        Backend.cancel(socket, __MODULE__, unquote(result_path), reason)
      end
    end
  end
end
