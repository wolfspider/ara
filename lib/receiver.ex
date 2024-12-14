defmodule Receiver do
  require Logger
  alias HttpStreamReader
  alias HttpRequest
  alias HttpServer

  def start(port) do
    case :gen_tcp.listen(port, [:binary, active: false, reuseaddr: true]) do
      {:ok, socket} ->
        Logger.info("Receiver listening on port #{port}")
        accept_connection(socket)
      {:error, reason} ->
        Logger.error("Could not start Receiver: #{inspect(reason)}.")
    end
  end

  def accept_connection(socket) do
    case :gen_tcp.accept(socket) do
      {:ok, client} ->
        spawn fn ->
          case Buffer.create() do
            {:ok, buffer_pid} ->
              Logger.warning("Buffer Created")
              serve(client, buffer_pid)

            {:error, {:already_started, buffer_pid}} ->
              Logger.warning("Buffer Already Started")
              serve(client, buffer_pid)

            unexpected ->
              Logger.error("Unexpected result from Buffer.create: #{inspect(unexpected)}")
          end
          Process.flag(:trap_exit, true)
        end
        accept_connection(socket)
      {:error, :closed} ->
        Logger.warning("#{__MODULE__} restarted, so the listen socket closed.")
      {:error, reason} ->
        Logger.error("ACCEPT ERROR: #{inspect reason}")
    end
  end

  def serve(socket, buffer_pid) do
    # Attempt to read and parse an HTTP request from the socket
    case HttpServer.serve(socket) do
      :ok ->
        #Logger.info("HTTP Request received: #{inspect(request)}")
        buffer_pid = maybe_recreate_buffer(buffer_pid)

        # Handle the HTTP request here, e.g., pass it to another process or module.

        # Continue serving for additional requests on the same connection
        serve(socket, buffer_pid)

      #{:error, :eof} ->
      #  Logger.info("Socket closed by client.")
      #  :ok # Gracefully stop serving

      #{:error, reason} ->
      #  Logger.error("HTTP parsing error: #{inspect(reason)}")
      #  :ok # Handle the error or gracefully stop serving
    end
  end

  defp maybe_recreate_buffer(original_pid) do
    if Process.alive?(original_pid) do
      original_pid
    else
      case Buffer.create() do
        {:ok, new_buffer_pid} ->
          new_buffer_pid

        {:error, reason} ->
          Logger.error("Failed to recreate buffer: #{inspect(reason)}")
          original_pid # Fall back to original PID, even if invalid
      end
    end
  end
end
