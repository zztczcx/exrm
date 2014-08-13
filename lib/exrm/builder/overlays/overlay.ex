defmodule ReleaseManager.Builder.Overlays.Overlay do
  @moduledoc """
  Defines an overlay to execute for the current release
  """

            # The type of overlay. Required
            # Valid values: :mkdirp, :copy, :template
  defstruct type: nil,
            # The source path for overlay commands (where applicable)
            source_path: "",
            # The target path for overlay commands (where applicable)
            target_path: "",
end