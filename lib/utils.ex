defmodule Utils do
  @moduledoc """
  Custom module for utility functions.
  """

  def stream_copy_to(input_stream, output_stream, length) do
    try do
      buffer_size = 128 * 1024
      bytes_copied = stream_do_copy(input_stream, output_stream, length, buffer_size, 0)
      {:ok, bytes_copied}
    rescue
      e in RuntimeError -> {:error, e.message}
    end
  end

  defp stream_do_copy(_input_stream, _output_stream, length, _buffer_size, position)
       when position >= length do
    # Reached the desired length, return the total bytes copied
    position
  end

  defp stream_do_copy(input_stream, output_stream, length, buffer_size, position) do
    remaining = min(buffer_size, length - position)

    case IO.binread(input_stream, remaining) do
      :eof ->
        # End of input stream, return the total bytes copied
        position

      {:error, reason} ->
        raise "Error reading from stream: #{inspect(reason)}"

      data when is_binary(data) ->
        IO.binwrite(output_stream, data)

        # Update the position and continue copying
        stream_do_copy(
          input_stream,
          output_stream,
          length,
          buffer_size,
          position + byte_size(data)
        )
    end
  end
end
