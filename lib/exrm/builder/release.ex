defmodule ReleaseManager.Builder.Release do
  @moduledoc """
  Defines metadata about a specific release.
  """

            # The name of the release
  defstruct name: "",
            # The version string for this release
            version: "0.0.1",
            # Use a specific version of ERTS for this release.
            # Valid values are false, or a version string, like `version`
            force_erts_vsn: false,
            # A list of Applications packaged in this release
            applications: [],
            # A list of Goals
            goals: []
end