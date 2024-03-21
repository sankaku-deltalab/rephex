ExUnit.start()

Mox.defmock(Rephex.Api.MockKernelApi, for: Rephex.Api.KernelApi)
Application.put_env(:rephex, :kernel_api, Rephex.Api.MockKernelApi)

Mox.defmock(Rephex.Api.MockLiveViewApi, for: Rephex.Api.LiveViewApi)
Application.put_env(:rephex, :live_view_api, Rephex.Api.MockLiveViewApi)

Mox.defmock(Rephex.Api.MockSystemApi, for: Rephex.Api.SystemApi)
Application.put_env(:rephex, :system_api, Rephex.Api.MockSystemApi)
