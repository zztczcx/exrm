defmodule ReleaseManager.Builder.Providers.Provider do
  @moduledoc """
  Defines behaviour and metadata for release providers
  """
  use Behaviour

  alias ReleaseManager.Builder.Configuration

  defcallback init(%Configuration{}    = configuration) :: {:ok, %Configuration{}} | {:error, term}
  defcallback execute(%Configuration{} = configuration) :: {:ok, %Configuration{}} | {:error, term}
end