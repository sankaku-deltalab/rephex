# defmodule RephexTest.AsyncAction do
#   use ExUnit.Case
#   use RephexTest.PropCheck
#   import Mox

#   setup :verify_on_exit!

#   alias RephexTest.Fixture

#   describe "start/2" do
#     property "call start_async if before_async returns {:continue, socket}" do
#       forall [payload, async_result] <- [map(atom(), term()), term()] do
#         socket = Fixture.new_socket_with_slices()
#         rpx_state = Rephex.State.Assigns.get_state(socket)

#         RephexTest.MockAsyncAction
#         |> expect(:before_async, fn socket, ^payload -> {:continue, socket} end)
#         |> expect(:start_async, fn ^rpx_state, ^payload, _send_msg -> async_result end)

#         Rephex.Api.MockLiveViewApi
#         |> expect(
#           :start_async,
#           fn socket,
#              {Rephex.AsyncAction.Handler, :result, Fixture.AsyncAction},
#              async_action_fun ->
#             async_action_fun.()
#             socket
#           end
#         )

#         ok = Fixture.AsyncAction.start(socket, payload) == socket

#         verify!()

#         ok
#       end
#     end

#     property "do not call start_async if before_async returns {:abort, socket}" do
#       forall [payload] <- [map(atom(), term())] do
#         socket = Fixture.new_socket_with_slices()

#         RephexTest.MockAsyncAction
#         |> expect(:before_async, fn socket, ^payload -> {:abort, socket} end)

#         ok = Fixture.AsyncAction.start(socket, payload) == socket

#         verify!()

#         ok
#       end
#     end
#   end
# end
