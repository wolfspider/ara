defmodule HttpRequest do
  alias HttpHeaders

  @moduledoc """
  Represents an HTTP request.
  """

  @typedoc "HTTP request structure"
  defstruct [:version, :method, :path, :headers]
  @type t :: %HttpRequest{
          version: HttpData.http_version,
          method: String.t(),
          path: String.t(),
          headers: HttpHeaders.t()
        }
end
