defmodule FindSiteIcon.CaptureAdapter do
  @moduledoc false

  # Req adapter that reports the fully merged request options back to the
  # calling process instead of performing a request. Lets tests assert on what
  # `do_get/3` and `do_head/3` build, which is otherwise not observable from
  # outside the module.

  @spec run(Req.Request.t()) :: {Req.Request.t(), Req.Response.t()}
  def run(request) do
    send(Req.Request.get_private(request, :test_pid), {:request_options, request.options})

    {request, Req.Response.new(status: 200, body: "")}
  end
end
