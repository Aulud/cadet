defmodule Cadet.Course.SourcecastUpload do
  @moduledoc """
  Represents an uploaded file for Sourcecast
  """
  use Arc.Definition
  use Arc.Ecto.Definition

  @env Mix.env()
  @extension_whitelist ~w(.wav)
  @versions [:original]

  def bucket, do: :cadet |> Application.fetch_env!(:uploader) |> Keyword.get(:sourcecasts_bucket)

  # Suppress no_match type error from Dialyzer (because @env is treated as a
  # constant)
  @dialyzer {:no_match, storage_dir: 2}
  def storage_dir(_, _) do
    if @env != :test do
      ""
    else
      env = Application.get_env(:cadet, :environment)
      "uploads/#{env}/sourcecasts"
    end
  end

  def validate({file, _}) do
    file_extension = file.file_name |> Path.extname() |> String.downcase()
    Enum.member?(@extension_whitelist, file_extension)
  end
end
