defmodule HttpData do
  alias HttpHeaders
  alias HttpCode
  alias HttpRequest
  alias HttpResponse

  @moduledoc """
  A module for common HTTP-related functionality, including version handling and body utilities.
  """
  defstruct [:version, :method, :path, :headers]
  @type t :: %__MODULE__{
    version: http_version,
    method: String.t(),
    path: String.t(),
    headers: HttpHeaders.t()
  }

  @typedoc "HTTP version representation"
  @type http_version :: :http_1_0 | :http_1_1 | {:http_other, String.t()}

  @typedoc "HTTP body representation"
  @type http_body :: {:raw, binary} | {:stream, Stream, non_neg_integer}

  @doc """
  Converts a string to an HTTP version.
  """
  @spec http_version_of_string(String.t()) :: http_version
  def http_version_of_string("1.0"), do: :http_1_0
  def http_version_of_string("1.1"), do: :http_1_1
  def http_version_of_string(version), do: {:http_other, version}

  @doc """
  Converts an HTTP version to a string.
  """
  @spec string_of_http_version(http_version) :: String.t()
  def string_of_http_version(:http_1_0), do: "1.0"
  def string_of_http_version(:http_1_1), do: "1.1"
  def string_of_http_version({:http_other, version}), do: version

  @doc """
  Returns the length of an HTTP body.
  """
  @spec http_body_length(http_body) :: non_neg_integer
  def http_body_length({:raw, binary}), do: byte_size(binary)
  def http_body_length({:stream, _stream, length}), do: length

  @doc """
  Creates an HTTP response from an HTTP code.
  """
  @spec http_response_of_code(HttpCode.t()) :: HttpResponse.t()
  def http_response_of_code(code) do
    message = {:raw, "HTTP #{HttpCode.message(code)}"}
    headers = HttpHeaders.from_list([{"Content-Type", "text/plain;charset=US-ASCII"}])

    %HttpResponse{
      code: code,
      headers: headers,
      body: message
    }
  end
end
