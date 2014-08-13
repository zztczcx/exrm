defmodule ReleaseManager.Builder.Overlays.Configuration do
  @moduledoc """
  Defines all variables to use when executing overlays.
  """
            # A keyword list of overlays/logging levels, which will be used
            # when determining the logging level for that overlay during execution
            # i.e. [mkdir: :debug]
  defstruct log: [],
            # The output directory for the built release
            output_dir: "",
            # A list of overriden application names
            overridden: [],
            # The directory for overrides
            overrides: "",
            # A list of user specified goals
            goals: [],
            # The list of all directories to search for code files.
            lib_dirs: [],
            # A list of current config files
            config_files: [],
            # A list of providers for this build (%Provider{})
            providers: [],
            # A path to the sys.config file location
            sys_config: "",
            # The root directory of the current project
            root_dir: ""
            # The default release for this build (%Release{})
            default_release: nil,
            # The current release being built (%Release{})
            current_release: nil
            # A list of applications in this release (%Application{})
            applications: [],

end