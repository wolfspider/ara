defmodule HttpStreamReader do
  require Logger

  @moduledoc """
  A module for reading and parsing HTTP requests from a socket.
  """

  alias HttpHeaders
  alias HttpHeadersBuilder
  alias HttpData
  alias HttpRequest

  @buffer_size 32_768
  @crlf "\r\n"

  @spec read_request(:gen_tcp.socket()) ::
          {:ok, HttpRequest.t()}
          | {:error,
             :eof | :invalid_request | :invalid_headers | {:no_translation, :unicode, :latin1}}
  def read_request(socket) do
    case read_line(socket, "") do
      {:ok, http_cmd, rest} when is_binary(http_cmd) ->
        case read_headers(rest) do
          {:ok, headers} ->
            parse_request(http_cmd, headers)

          {:error, reason} ->
            {:error, {:invalid_headers, reason}}
        end

      {:error, :eof} ->
        Logger.info("Client disconnected after completing the request.")
        {:error, :eof} # Gracefully terminate serving
      {:error, :closed} ->
        Logger.info("Socket closed by client.")
        {:error, :closed} # Gracefully terminate serving

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp read_line(full_buffer) do
    case String.split(full_buffer, @crlf, parts: 2) do
      [line, rest] ->
        {:ok, line, rest}

      _ ->
        # Incomplete line, continue reading
        read_line(full_buffer)
    end
  end

  defp read_line(socket, buffer) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, data} ->
        full_buffer = buffer <> data

        case String.split(full_buffer, @crlf, parts: 2) do
          [line, rest] ->
            {:ok, line, rest}

          _ ->
            # Incomplete line, continue reading
            read_line(socket, full_buffer)
        end

      {:error, :closed} ->
        if buffer == "" do
          {:error, :eof}
        else
          {:ok, buffer}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp read_headers(line) do
    read_headers(line, HttpHeadersBuilder.new())
  end

  defp read_headers(rest, headers) do
    case read_line(rest) do
      {:ok, "", _cont} ->
        # End of headers
        {:ok, HttpHeadersBuilder.headers(headers)}

      {:ok, line, cont} ->
        Logger.info("Header line read: #{inspect(line)}")

        case Regex.named_captures(~r/^(?<key>[a-zA-Z0-9-]+):\s*(?<value>.+)$/, line) do
          %{"key" => key, "value" => value} ->
            Logger.info("Parsed header: #{inspect(key)} => #{inspect(value)}")
            read_headers(cont, HttpHeadersBuilder.push(headers, key, value))

          nil ->
            Logger.info("Line did not match header format, trying continuation: #{inspect(line)}")

            case Regex.named_captures(~r/^\s+(?<value>.+)$/, line) do
              %{"value" => continuation} ->
                Logger.info("Continuation detected: #{inspect(continuation)}")
                read_headers(cont, HttpHeadersBuilder.push_continuation(headers, continuation))

              nil ->
                Logger.error("Invalid header line format: #{inspect(line)}")
                {:error, :invalid_header_format}
            end
        end
    end
  end

  defp parse_request(http_cmd, headers) do
    case Regex.named_captures(
           ~r/^(?<method>[A-Z]+) (?<path>\S+) HTTP\/(?<version>\d+\.\d+)$/,
           http_cmd
         ) do
      %{"method" => method, "path" => path, "version" => version} ->
        {:ok,
         %HttpRequest{
           version: HttpData.http_version_of_string(version),
           method: String.upcase(method),
           path: URI.decode(path),
           headers: headers
         }}

      nil ->
        {:error, :invalid_http_command}
    end
  end
end
