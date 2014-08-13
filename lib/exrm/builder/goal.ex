defmodule ReleaseManager.Builder.Goal do
  @moduledoc """
  Defines the metadata for a goal, which defines
  the constraints for resolving applications and
  their versions when building a release.
  """

            # The atom name of the application for this goal
  defstruct application: nil,
            # The version number to use during resolution
            version: "0.0.1",
            # The constraint to use when comparing versions
            # Valid values are the same as version requirements
            # as specified in `Elixir.Version`.
            requirement: "~> 0.0.1"
end