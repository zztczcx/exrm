defmodule ReleaseManager.Builder.Application do
  @moduledoc """
  Defines metadata about a specific OTP application
  """


            # The atom name of the application
  defstruct name: :undefined,
            # The version of this application
            version: "0.0.1"
            # The start type of this application
            # Valid values are: :permanent, :transient, :temporary, :load, and :none
            # If the type is :permanent, :transient, or :temporary, the application
            # will be loaded and started (using the semantics of that type). If type
            # is :load, the application will only be loaded. If the type is :none,
            # the application will be neither loaded or started, however the code will
            # still be loaded. Defaults to :permanent
            type: :permanent,
            # A list of applications included by this application.
            # included_apps should be provided as a list of atoms.
            included_apps: [],
            # The location of this application on disk
            dir: "",
            # The list of active application dependencies for this app
            active_dependencies: [],
            # The list of library application dependencies for this app
            lib_dependencies: [],
            # Whether this application should be linked in or not
            link?: false
end