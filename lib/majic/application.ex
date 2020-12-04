defmodule Majic.Application do
  use Application
  require Logger
  @default_db_term Majic.DefaultDatabase
  @moduledoc false

  # Majic library does not supervises any processes-- this is just to ensure that the built-in mgc database can be
  # loaded, and recompile it a runtime if not.

  def start(_, _) do
    if default = Application.get_env(:majic, :default_database) do
      set_default_database(default)
      {:ok, self()}
    else
      valid_database?(Majic.valid_database?(priv("/magic.mgc")))
    end
  end

  def get_default_database do
    :persistent_term.get(@default_db_term)
  end

  defp valid_database?(true) do
    set_default_database(database())
    {:ok, self()}
  end

  defp valid_database?(false) do
    built_database?(runtime_compile())
  end

  defp built_database?(:ok) do
    Logger.info("Majic: rebuilt magic database")
    set_default_database(database())
    {:ok, self()}
  end

  defp built_database?(_error) do
    Logger.error(
      "Majic: Could not use magic database."
    )

    {:error, :no_magic_database}
  end

  defp database do
    priv("/magic.mgc")
  end

  defp set_default_database(default) do
    :persistent_term.put(@default_db_term, default)
  end

  defp runtime_compile do
    src = priv("/magic")

    case Majic.compile(src) do
      {:ok, _} ->
        File.cp!("magic.mgc", priv("/magic.mgc"))
        File.rm!("magic.mgc")
        :ok

      error ->
        error
    end
  end

  defp priv(path) do
    Path.join(to_string(:code.priv_dir(:majic)), path)
  end
end
