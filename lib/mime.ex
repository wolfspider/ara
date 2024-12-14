defmodule Mime do
  @moduledoc """
  A module for handling MIME type mappings.
  """

  @type mime :: String.t()
  @type mime_map :: %{}

  @doc """
  Canonizes a file extension by ensuring it starts with a dot and is lowercase.
  """
  @spec canonize_ext(String.t()) :: String.t()
  def canonize_ext(ext) do
    ext
    |> String.trim()
    |> String.downcase()
    |> (fn e -> if String.starts_with?(e, "."), do: e, else: "." <> e end).()
  end

  @doc """
  Binds a file extension to a MIME type.
  """
  @spec bind(mime_map(), String.t(), mime()) :: mime_map()
  def bind(mimes, ext, mime_type) do
    ext = canonize_ext(ext)

    if ext == "." do
      raise ArgumentError, "cannot bind empty extension"
    end

    Map.put(mimes, ext, mime_type)
  end

  @doc """
  Looks up a MIME type by its file extension.
  """
  @spec lookup(mime_map(), String.t()) :: mime() | nil
  def lookup(mimes, ext) do
    Map.get(mimes, canonize_ext(ext))
  end

  @doc """
  Processes a stream of MIME type definitions and returns a mime_map.
  """
  @spec of_stream(Enumerable.t()) :: mime_map()
  def of_stream(stream) do
    stream
    |> Stream.map(&process_line/1)
    |> Task.async_stream(&process_mime/1, max_concurrency: System.schedulers_online())
    |> Enum.reduce(%{}, fn
      {:ok, {mime, exts}}, acc ->
        Enum.reduce(exts, acc, fn ext, acc ->
          bind(acc, ext, mime)
        end)

      _other, acc ->
        acc
    end)
  end

  @doc """
  Reads a file and processes it as a MIME type definition.
  """
  @spec of_file(String.t()) :: mime_map()
  def of_file(filename) do
    try do
      File.stream!(filename, :line)
      |> of_stream()
    rescue
      e in File.Error ->
        IO.warn("Error opening file: #{e}")
        %{} # Return an empty mime_map in case of errors
    end
  end

  defp process_line(line) do
    line
    |> String.trim()
    |> String.replace(~r/#.*$/, "") # Remove comments
    |> case do
      "" -> nil
      valid_line ->
        [ctype | exts] = String.split(valid_line, ~r/\s+/, trim: true)
        {ctype, exts}
    end
  end

  defp process_mime(nil), do: nil
  defp process_mime(line), do: line
end
