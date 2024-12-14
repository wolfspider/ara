defmodule HttpHeaders do
  @moduledoc """
  A module for handling HTTP headers.
  """

  @content_length "content-length"
  @content_type "content-type"

  defstruct headers: %{}

  @type t :: %__MODULE__{headers: %{String.t() => list(String.t())}}

  defp normalize_key(key) when is_binary(key), do: String.trim(String.downcase(key))

  @doc """
  Create a new HttpHeaders struct from a list of key-value pairs.
  """
  @spec from_list([{String.t(), String.t()}]) :: t()
  def from_list(headers) do
    headers
    |> Enum.reduce(%HttpHeaders{}, fn {key, value}, acc ->
      add(acc, key, value)
    end)
  end

  @doc """
  Convert headers to a list of key-value pairs.
  """
  @spec to_list(t()) :: [{String.t(), String.t()}]
  def to_list(%HttpHeaders{headers: headers}) do
    Map.to_list(headers)
  end

  @doc """
  Check if a header exists by key.
  """
  @spec exists?(t(), String.t()) :: boolean()
  def exists?(%HttpHeaders{headers: headers}, key) do
    Map.has_key?(headers, normalize_key(key))
  end

  @doc """
  Get the value of a header by key, or nil if not found.
  """
  @spec get(t(), String.t()) :: String.t() | nil
  def get(%HttpHeaders{headers: headers}, key) do
    Map.get(headers, normalize_key(key))
  end

  @doc """
  Set a header, replacing any existing headers with the same key.
  """
  @spec set(t(), String.t(), String.t()) :: t()
  def set(%HttpHeaders{} = http_headers, key, value) do
    normalized_key = normalize_key(key)

    %HttpHeaders{
      http_headers
      | headers: Map.put(http_headers.headers, normalized_key, [value])
    }
  end

  @doc """
  Add a header, allowing duplicate keys.
  """
  @spec add(t(), String.t(), String.t()) :: t()
  def add(%HttpHeaders{} = http_headers, key, value) do
    normalized_key = normalize_key(key)

    updated_headers =
      Map.update(http_headers.headers, normalized_key, [value], fn existing ->
        [value | existing]
      end)

    %HttpHeaders{http_headers | headers: updated_headers}
  end

  @doc """
  Get the content length as an integer if it exists.
  """
  @spec content_length(t()) :: integer() | nil
  def content_length(%HttpHeaders{} = http_headers) do
    case get(http_headers, @content_length) do
      nil -> nil
      value ->
        case Integer.parse(value) do
          {int_value, _} -> int_value
          _ -> raise ArgumentError, "Invalid content-length value"
        end
    end
  end
end

defmodule HttpHeadersBuilder do
  @moduledoc """
  A builder module for constructing HttpHeaders structs incrementally.
  """

  defstruct last_seen: nil, headers: %HttpHeaders{}

  @type t :: %__MODULE__{
          last_seen: nil | {String.t(), String.t()},
          headers: HttpHeaders.t()
        }

  def new do
    %HttpHeadersBuilder{}
  end

  @doc """
  Push a new header key-value pair.
  """
  @spec push(t(), String.t(), String.t()) :: t()
  def push(%HttpHeadersBuilder{} = builder, key, value) do
    builder
    |> maybe_pop()
    |> Map.put(:last_seen, {key, String.trim(value)})
  end

  @doc """
  Push a continuation line for the last header.
  """
  @spec push_continuation(t(), String.t()) :: t()
  def push_continuation(%HttpHeadersBuilder{last_seen: nil}), do: raise "InvalidHttpHeaderContinuation"

  def push_continuation(%HttpHeadersBuilder{} = builder, value) do
    {key, prev_value} = builder.last_seen

    %HttpHeadersBuilder{
      builder
      | last_seen: {key, "#{prev_value} #{String.trim(value)}"}
    }
  end

  @doc """
  Get the headers as a HttpHeaders struct.
  """
  @spec headers(t()) :: HttpHeaders.t()
  def headers(%HttpHeadersBuilder{} = builder) do
    builder
    |> maybe_pop()
    |> Map.get(:headers)
  end

  defp maybe_pop(%HttpHeadersBuilder{last_seen: nil} = builder), do: builder

  defp maybe_pop(%HttpHeadersBuilder{last_seen: {key, value}, headers: headers} = builder) do
    updated_headers = HttpHeaders.add(headers, key, value)

    %HttpHeadersBuilder{
      builder
      | last_seen: nil,
        headers: updated_headers
    }
  end
end
