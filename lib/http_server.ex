defmodule HttpServer do
  require Logger
  alias HttpRequest
  alias HttpResponse
  alias HttpHeaders
  alias HttpStreamReader
  alias HttpData

  @doc """
  Handles an incoming client connection, processes HTTP requests, and sends responses.
  """
  def serve(client_socket) do
    with {:ok, request} <- HttpStreamReader.read_request(client_socket),
         {:ok, response} <- handle_request(request) do
      send_response(client_socket, response)
      # Uncomment this if you want to continue serving after handling the request
      # serve(client_socket)
    else
      {:error, :eof} ->
        Logger.info("Client disconnected.")
        :ok

      {:error, reason} ->
        Logger.error("Error processing request: #{inspect(reason)}")
        error_response = generate_error_response(HttpCode.code(:HTTP_500))
        send_response(client_socket, error_response)

    end
  end

  defp handle_request(%HttpRequest{} = request) do
    case request.method do
      "GET" -> serve_static(request)
      _ -> {:ok, generate_error_response(HttpCode.code(:HTTP_405))}
    end
  end

  defp serve_static(%HttpRequest{path: path}) do
    full_path = canonical_path(path)

    case File.stat(full_path) do
      {:ok, %File.Stat{type: :regular}} ->
        send_file_response(full_path)

      {:error, :enoent} ->
        {:ok, generate_error_response(HttpCode.code(:HTTP_404))}

      {:error, reason} ->
        Logger.error("Error accessing file: #{inspect(reason)}")
        {:ok, generate_error_response(HttpCode.code(:HTTP_500))}
    end
  end

  defp send_file_response(file_path) do
    with {:ok, file_content} <- File.read(file_path),
         {:ok, mime_type} <- guess_mime_type(file_path) do
      {:ok,
       %HttpResponse{
         code: HttpCode.code(:HTTP_200),
         headers: HttpHeaders.from_list([
           {"Content-Type", mime_type},
           {"Content-Length", Integer.to_string(byte_size(file_content))}
         ]),
         body: {:raw, file_content}
       }}
    else
      {:error, _reason} -> {:ok, generate_error_response(HttpCode.code(:HTTP_500))}
    end
  end

  defp guess_mime_type(file_path) do
    case Path.extname(file_path) do
      ".html" -> {:ok, "text/html"}
      ".css" -> {:ok, "text/css"}
      ".js" -> {:ok, "application/javascript"}
      ".json" -> {:ok, "application/json"}
      ".jpg" -> {:ok, "image/jpeg"}
      ".png" -> {:ok, "image/png"}
      _ -> {:ok, "application/octet-stream"}
    end
  end

  defp generate_error_response(http_code) do
    %HttpResponse{
      code: http_code,
      headers: HttpHeaders.from_list([
        {"Content-Type", "text/plain"}
      ]),
      body: {:raw, "Error #{HttpCode.code(http_code)}: #{HttpCode.status(http_code)}\n"}
    }
  end

  defp send_response(socket, %HttpResponse{} = response) do
    Logger.info("Serving response: #{inspect(response)}")
    :ok = send_status_line(socket, response)
    :ok = send_headers(socket, response.headers)
    :ok = send_body(socket, response.body)
  end

  defp send_status_line(socket, %HttpResponse{code: code}) do
    status_text = HttpCode.status(code)
    line = "HTTP/1.1 #{HttpCode.code(code)} #{status_text}\r\n"
    Logger.info("Status line sent: #{inspect(line)}")
    :gen_tcp.send(socket, line)
  end

  defp send_headers(socket, %HttpHeaders{headers: headers}) do
    headers
    |> Enum.each(fn {key, value} ->
      line = "#{key}: #{value}\r\n"
      :gen_tcp.send(socket, line)
    end)
    :gen_tcp.send(socket, "\r\n")
  end

  defp send_body(socket, {:raw, body}) when is_binary(body) do
    :gen_tcp.send(socket, body)
  end

  defp canonical_path(path) when is_binary(path) do
    path
    |> String.split("/", trim: true) # Split by "/", trimming empty segments
    |> Enum.reduce([], fn
      ".", acc -> acc # Ignore current directory segments
      "..", [_ | rest] -> rest # Remove the last valid segment on ".."
      "..", [] -> [] # No-op if there’s no segment to go back to
      segment, acc -> [segment | acc] # Add valid segments
    end)
    |> Enum.reverse() # Reverse the segments to reconstruct the path
    |> Enum.join("/") # Join the segments with "/"
  end
end
