ExUnit.start()

Mox.defmock(Rephex.Api.MockKernelApi, for: Rephex.Api.KernelApi)
Application.put_env(:rephex, :kernel_api, Rephex.Api.MockKernelApi)

Mox.defmock(Rephex.Api.MockLiveViewApi, for: Rephex.Api.LiveViewApi)
Application.put_env(:rephex, :live_view_api, Rephex.Api.MockLiveViewApi)

Mox.defmock(RephexTest.MockAsyncAction, for: RephexTest.Api.AsyncAction)
Application.put_env(:rephex_test, :async_action_api, RephexTest.MockAsyncAction)
