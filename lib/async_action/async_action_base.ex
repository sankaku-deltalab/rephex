defmodule Rephex.AsyncAction.Base do
  alias Phoenix.LiveView.Socket

  @type result :: any()
  @type cancel_reason :: any()
  @type message :: any()

  @callback resolve(
              socket :: Socket.t(),
              result :: {:ok, result()} | {:exit, cancel_reason()}
            ) :: Socket.t()

  @callback receive_message(socket :: Socket.t(), message :: message()) :: Socket.t()
end

defmodule Rephex.AsyncAction.Handler do
  alias Phoenix.LiveView.Socket

  defmacro __using__(_opt \\ []) do
    quote do
      @dialyzer {:nowarn_function, handle_async: 3}

      @impl true
      def handle_info(
            {Rephex.AsyncAction.Handler, :message, async_module, _message} = msg,
            %Socket{} = socket
          )
          when is_atom(async_module) do
        Rephex.AsyncAction.Handler.handle_info_by_async_message(msg, socket)
      end

      @impl true
      def handle_async(
            {Rephex.AsyncAction.Handler, :result, async_module} = name,
            async_fun_result,
            %Socket{} = socket
          ) do
        Rephex.AsyncAction.Handler.handle_async_action(name, async_fun_result, socket)
      end
    end
  end

  def start_async_by_action(%Socket{} = socket, async_module, fun_for_async)
      when is_atom(async_module) and is_function(fun_for_async, 0) do
    Phoenix.LiveView.start_async(
      socket,
      {Rephex.AsyncAction.Handler, :result, async_module},
      fun_for_async
    )
  end

  def cancel_async_by_action(%Socket{} = socket, async_module, reason)
      when is_atom(async_module) do
    Phoenix.LiveView.cancel_async(
      socket,
      {Rephex.AsyncAction.Handler, :result, async_module},
      reason
    )
  end

  def send_message_from_action(lv_pid, async_module, message)
      when is_atom(async_module) and is_pid(lv_pid) do
    send(lv_pid, {Rephex.AsyncAction.Handler, :message, async_module, message})
  end

  def handle_info_by_async_message(
        {Rephex.AsyncAction.Handler, :message, async_module, message} = _msg,
        %Socket{} = socket
      )
      when is_atom(async_module) do
    if socket.parent_pid != nil,
      do: raise("Must not receive message in async on propagated state.")

    {:noreply, async_module.receive_message(socket, message)}
  end

  def handle_async_action(
        {Rephex.AsyncAction.Handler, :result, async_module},
        async_fun_result,
        %Socket{} = socket
      )
      when is_atom(async_module) do
    {:noreply, async_module.resolve(socket, async_fun_result)}
  end
end
