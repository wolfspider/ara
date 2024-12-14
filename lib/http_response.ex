defmodule HttpResponse do
  alias HttpHeaders
  alias HttpCode

  @moduledoc """
  Represents an HTTP response.
  """

  @typedoc "HTTP response structure"
  defstruct [:code, :headers, :body]
  @type t :: %HttpResponse{
          code: HttpCode.t(),
          headers: HttpHeaders.t(),
          body: HttpData.http_body
        }
end
