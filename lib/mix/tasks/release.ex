defmodule Mix.Tasks.Release do
  @moduledoc """
  Build a release for the current mix application.

  ## Examples

      # Build a release using defaults
      mix release

      # Pass args to erlexec when running the release
      mix release --erl="-env TZ UTC"

      # Enable dev mode. Make changes, compile using MIX_ENV=prod
      # and execute your release again to pick up the changes
      mix release --dev

      # Set the verbosity level
      mix release --verbosity=[silent|quiet|normal|verbose]

  You may pass any number of arguments as needed. Make sure you pass arguments
  using `--key=value`, not `--key value`, as the args may be interpreted incorrectly
  otherwise.

  """
  @shortdoc "Build a release for the current mix application."

  use    Mix.Task
  import ReleaseManager.Utils
  alias  ReleaseManager.Utils
  alias  ReleaseManager.Config

  @_RELXCONF    "relx.config"
  @_BOOT_FILE   "boot"
  @_NODETOOL    "nodetool"
  @_SYSCONFIG   "sys.config"
  @_VMARGS      "vm.args"
  @_RELEASE_DEF "release_definition.txt"
  @_RELEASES    "{{{RELEASES}}}"
  @_NAME        "{{{PROJECT_NAME}}}"
  @_VERSION     "{{{PROJECT_VERSION}}}"
  @_ERTS_VSN    "{{{ERTS_VERSION}}}"
  @_ERL_OPTS    "{{{ERL_OPTS}}}"
  @_LIB_DIRS    "{{{LIB_DIRS}}}"

  def run(args) do
    if Mix.Project.umbrella? do
      config = [umbrella?: true]
      for %Mix.Dep{app: app, opts: opts} <- Mix.Dep.Umbrella.loaded do
        Mix.Project.in_project(app, opts[:path], config, fn _ -> do_run(args) end)
      end
    else
      do_run(args)
    end
  end

  defp do_run(args) do
    # Start with a clean slate
    Mix.Tasks.Release.Clean.do_cleanup(:build)
    # Collect release configuration
    config = parse_args(args)
    info "Building release with MIX_ENV=#{config.env}."
    # Begin release pipeline
    config
    |> build_project
    |> generate_relx_config
    |> generate_sys_config
    |> generate_vm_args
    |> generate_boot_script
    |> execute_before_hooks
    |> do_release
    |> generate_nodetool
    |> execute_after_hooks
    |> update_release_package

    info "The release for #{config.name}-#{config.version} is ready!"
  end

  defp build_project(%Config{verbosity: verbosity, env: env} = config) do
    # Fetch deps, and compile, using the prepared Elixir binaries
    cond do
      verbosity == :verbose ->
        mix "deps.get",     env, :verbose
        mix "compile",      env, :verbose
      true ->
        mix "deps.get",     env
        mix "compile",      env
    end
    # Continue...
    config
  end

  defp generate_relx_config(%Config{name: name, version: version, env: env} = config) do
    debug "Generating relx configuration..."
    # Get paths
    rel_def  = rel_file_source_path @_RELEASE_DEF
    source   = rel_source_path @_RELXCONF
    dest     = rel_file_dest_path @_RELXCONF
    # Get relx.config template contents
    relx_config = source |> File.read!
    # Get release definition template contents
    tmpl = rel_def |> File.read!
    # Generate release configuration for historical releases
    releases = get_releases(name)
      |> Enum.map(fn {rname, rver} -> tmpl |> replace_release_info(rname, rver) end)
      |> Enum.join
    # Set upgrade flag if this is an upgrade release
    config = case releases do
      "" -> config
      _  -> %{config | :upgrade? => true}
    end
    elixir_path = get_elixir_path() |> Path.join("lib") |> String.to_char_list
    lib_dirs = case Mix.Project.config |> Keyword.get(:umbrella?, false) do
      true ->
        [ elixir_path,
          '#{"_build/#{env}" |> Path.expand}',
          '#{Mix.Project.config |> Keyword.get(:deps_path) |> Path.expand}' ]
      _ ->
        [ elixir_path,
          '#{"_build/#{env}" |> Path.expand}' ]
    end
    # Build release configuration
    relx_config = relx_config
      |> String.replace(@_RELEASES, releases)
      |> String.replace(@_LIB_DIRS, :io_lib.fwrite('~p.\n\n', [{:lib_dirs, lib_dirs}]) |> List.to_string)
    # Replace placeholders for current release
    relx_config = relx_config |> replace_release_info(name, version)
    # Read config as Erlang terms
    relx_config = Utils.string_to_terms(relx_config)
    # Merge user provided relx.config
    user_config_path = rel_dest_path @_RELXCONF
    merged = case user_config_path |> File.exists? do
      true  ->
        debug "Merging custom relx configuration from #{user_config_path |> Path.relative_to_cwd}..."
        case Utils.read_terms(user_config_path) do
          []                                      -> relx_config
          [{_, _}|_] = user_config                -> Utils.merge(relx_config, user_config)
          [user_config] when is_list(user_config) -> Utils.merge(relx_config, user_config)
          [user_config]                           -> Utils.merge(relx_config, [user_config])
        end
      _ ->
        relx_config
    end
    # Save relx config for use later
    config = %{config | :relx_config => merged}
    # Ensure destination base path exists
    dest |> Path.dirname |> File.mkdir_p!
    # Persist relx.config
    Utils.write_terms(dest, merged)
    # Return the project config after we're done
    config
  end

  defp generate_sys_config(%Config{env: env} = config) do
    default_sysconfig = rel_file_source_path @_SYSCONFIG
    user_sysconfig    = rel_dest_path @_SYSCONFIG
    dest              = rel_file_dest_path   @_SYSCONFIG

    debug "Generating sys.config..."
    # Read in current project config
    project_conf = load_config(env)
    # Merge project config with either the user-provided config, or the default sys.config we provide.
    # If a sys.config is provided by the user, it will take precedence over project config. If the
    # default sys.config is used, the project config will take precedence instead.
    merged = case user_sysconfig |> File.exists? do
      true ->
        debug "Merging custom sys.config from #{user_sysconfig |> Path.relative_to_cwd}..."
        # User-provided
        case user_sysconfig |> Utils.read_terms do
          []                                  -> project_conf
          [user_conf] when is_list(user_conf) -> Mix.Config.merge(project_conf, user_conf)
          [user_conf]                         -> Mix.Config.merge(project_conf, [user_conf])
        end
      _ ->
        # Default
        [default_conf] = default_sysconfig |> Utils.read_terms
        Mix.Config.merge(default_conf, project_conf)
    end
    # Ensure parent directory exists prior to writing
    File.mkdir_p!(dest |> Path.dirname)
    # Write the config to disk
    dest |> Utils.write_term(merged)
    # Continue..
    config
  end

  defp generate_vm_args(%Config{version: version} = config) do
    vmargs_path = Utils.rel_dest_path("vm.args")
    if vmargs_path |> File.exists? do
      debug "Generating vm.args..."
      relx_config_path = Utils.rel_file_dest_path("relx.config")
      # Read in relx.config
      relx_config = relx_config_path |> Utils.read_terms
      # Update configuration to add new overlay for vm.args
      overlays = [overlay: [
        {:copy, vmargs_path |> String.to_char_list, 'releases/#{version}/vm.args'}
      ]]
      updated = Utils.merge(relx_config, overlays)
      # Persist relx.config
      Utils.write_terms(relx_config_path, updated)
    end
    # Continue..
    config
  end

  defp generate_boot_script(%Config{name: name, version: version, erl: erl_opts} = config) do
    erts = :erlang.system_info(:version) |> IO.iodata_to_binary
    boot = rel_file_source_path @_BOOT_FILE
    dest = rel_file_dest_path   @_BOOT_FILE
    # Ensure destination base path exists
    debug "Generating boot script..."
    contents = File.read!(boot)
      |> String.replace(@_NAME, name)
      |> String.replace(@_VERSION, version)
      |> String.replace(@_ERTS_VSN, erts)
      |> String.replace(@_ERL_OPTS, erl_opts)
    File.write!(dest, contents)
    # Make executable
    dest |> chmod("+x")
    # Continue..
    config
  end

  defp execute_before_hooks(%Config{} = config) do
    plugins = ReleaseManager.Plugin.load_all
    Enum.reduce plugins, config, fn plugin, conf ->
      try do
        # Handle the case where a child plugin does not return the configuration
        case plugin.before_release(conf) do
          %Config{} = result -> result
          _                  -> conf
        end
      rescue
        exception ->
          stacktrace = System.stacktrace
          error "Failed to execute before_release hook for #{plugin}!"
          reraise exception, stacktrace
      end
    end
  end

  defp execute_after_hooks(%Config{} = config) do
    plugins = ReleaseManager.Plugin.load_all
    Enum.reduce plugins, config, fn plugin, conf ->
      try do
        # Handle the case where a child plugin does not return the configuration
        case plugin.after_release(conf) do
          %Config{} = result -> result
          _                  -> conf
        end
      rescue
        exception ->
          stacktrace = System.stacktrace
          error "Failed to execute after_release hook for #{plugin}!"
          reraise exception, stacktrace
      end
    end
  end

  defp do_release(%Config{name: name, version: version, verbosity: verbosity, upgrade?: upgrade?, dev: dev_mode?, env: env} = config) do
    debug "Generating release..."
    # If this is an upgrade release, generate an appup
    if upgrade? do
      # Change mix env for appup generation
      with_env env, fn ->
        # Generate appup
        app      = name |> String.to_atom
        v1       = get_last_release(name)
        v1_path  = rel_dest_path [name, "lib", "#{name}-#{v1}"]
        v2_path  = Mix.Project.config |> Mix.Project.compile_path |> String.replace("/ebin", "")
        own_path = rel_dest_path "#{name}.appup"
        # Look for user's own .appup file before generating one
        case own_path |> File.exists? do
          true ->
            # Copy it to ebin
            case File.cp(own_path, Path.join([v2_path, "/ebin", "#{name}.appup"])) do
              :ok ->
                info "Using custom .appup located in rel/#{name}.appup"
              {:error, reason} ->
                error "Unable to copy custom .appup file: #{reason}"
                abort!
            end
          _ ->
            # No custom .appup found, proceed with autogeneration
            case ReleaseManager.Appups.make(app, v1, version, v1_path, v2_path) do
              {:ok, _}         ->
                info "Generated .appup for #{name} #{v1} -> #{version}"
              {:error, reason} ->
                error "Appup generation failed with #{reason}"
                abort!
            end
        end
      end
    end
    # Do release
    case relx name, version, verbosity, upgrade?, dev_mode? do
      :ok ->
        # Clean up template files
        Mix.Tasks.Release.Clean.do_cleanup(:relfiles)
        # Continue..
        config
      {:error, message} ->
        error message
        abort!
    end
  end

  defp generate_nodetool(%Config{name: name} = config) do
    debug "Generating nodetool..."
    nodetool = rel_file_source_path @_NODETOOL
    dest     = rel_dest_path [name, "bin", @_NODETOOL]
    # Copy
    File.cp! nodetool, dest
    # Make executable
    dest |> chmod("+x")
    # Continue..
    config
  end

  defp update_release_package(%Config{name: name, version: version, relx_config: relx_config} = config) do
    debug "Packaging release..."
    erts = "erts-#{:erlang.system_info(:version) |> IO.iodata_to_binary}"
    # Delete original release package
    tarball = rel_dest_path [name, "#{name}-#{version}.tar.gz"]
    File.rm! tarball
    # Make sure we have a start.boot file for upgrades/downgrades
    source_boot = rel_dest_path([name, "releases", version, "#{name}.boot"])
    dest_boot   = rel_dest_path([name, "releases", version, "start.boot"])
    File.cp! source_boot, dest_boot
    # Get include_erts value from relx_config
    include_erts = Keyword.get(relx_config, :include_erts, true)
    extras = case include_erts do
      false -> []
      _     -> [{'#{erts}', '#{rel_dest_path([name, erts])}'}]
    end
    # Re-package release with modifications
    file_list = File.ls!(rel_dest_path(name))
      |> Enum.reject(&(&1 == erts))
      |> Enum.map(&({'#{&1}', '#{rel_dest_path([name, &1])}'}))
    :ok = :erl_tar.create(
      '#{tarball}',
      file_list ++ extras,
      [:compressed]
    )
    # Continue..
    config
  end

  defp parse_args(argv) do
    {args, _, _} = OptionParser.parse(argv)
    defaults = %Config{
      name:    Mix.Project.config |> Keyword.get(:app) |> Atom.to_string,
      version: Mix.Project.config |> Keyword.get(:version),
      env:     Mix.env
    }
    Enum.reduce args, defaults, fn arg, config ->
      case arg do
        {:verbosity, verbosity} ->
          %{config | :verbosity => String.to_atom(verbosity)}
        {key, value} ->
          Map.put(config, key, value)
      end
    end
  end

  defp replace_release_info(template, name, version) do
    template
    |> String.replace(@_NAME, name)
    |> String.replace(@_VERSION, version)
  end

end
