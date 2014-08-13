defmodule ReleaseManager.Builder.Configuration do
  @moduledoc """
  Defines the current configuration for the release builder.
  """

            # Which directories to search for OTP applications when resolving deps.
  defstruct lib_dirs: [], 
            # These are additional code paths to search for custom Providers
            paths: [],
            # If a custom sys.config is provided, this is the path to it.
            sys_config: false,
            # Specify whether or not to generate the default start script
            generate_start_script: true,
            # Provide a path instead of false to set variables for overlays.
            # See `Overlays.Configuration` for more info.
            overlay_config: false
            # See documentation for `Overlays.Overlay`
            overlays: [],
            # Specifies whether to bundle a specific version of ERTS
            # with this release. Valid values are false (do not include ERTS),
            # true (include the current version of ERTS), or a path to
            # the version of ERTS you wish to bundle ("/path/to/erlang").
            include_erts: true,
            # Whether or not to include source files for the applications
            # in this release.
            include_src?: false,
            # The default relase to build (%Release{})
            default_release: nil,
            # A list of `%Release{}` defining 
            releases: [],
            # A list of application overrides to use for this release.
            # The overridden application will be symlinked into the release
            # Should be a keyword list of [application: "/path/to/app"]
            overrides: [],
            # A list of provider modules to use during this release.
            # Order is important, as providers will be executed in
            # the order of appearance in this list. See `Provider` for
            # further info.
            providers: [],
            # A list of providers to run after all other providers. Again
            # order is important.
            add_providers: [],


end