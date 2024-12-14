defmodule ARA do
  require Logger
  @moduledoc """
  Documentation for `ARA`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> ARA.hello()
      :world

  """
  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: ARA.TaskSupervisor}
    ]

    opts = [strategy: :one_for_one, name: ARA.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, _pid} ->
        # Start the Receiver task and store its PID
        case Task.Supervisor.start_child(ARA.TaskSupervisor, fn -> Receiver.start(5555) end) do
          {:ok, receiver_pid} ->
            Process.put(:receiver_pid, receiver_pid) # Store the PID in the process dictionary
            :ok
          {:error, reason} ->
            Logger.error("Failed to start Receiver: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Failed to start Supervisor: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def shutdown do
    receiver_pid = Process.get(:receiver_pid)

    if receiver_pid do
      Logger.info("Attempting to terminate Receiver task with PID #{inspect(receiver_pid)}")

      case Task.Supervisor.terminate_child(ARA.TaskSupervisor, receiver_pid) do
        :ok ->
          IO.puts("Receiver task stopped successfully.")
        {:error, :not_found} ->
          IO.puts("Receiver task not found; it might have already stopped.")
      end
    else
      IO.puts("No Receiver PID found.")
    end

    # Stop the Supervisor and its children
    case Supervisor.stop(ARA.Supervisor, :normal, :infinity) do
      :ok ->
        IO.puts("Application stopped successfully.")
    end
  end

  def hello do
    IO.puts("HTTP Code: #{HttpCode.code(:HTTP_200)}")
    IO.puts("Status: #{HttpCode.status(:HTTP_200)}")
    IO.puts("Message: #{HttpCode.message(:HTTP_200)}")
    :world
  end
end
