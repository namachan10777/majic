defmodule Mix.Tasks.Compile.Majic do
  use Mix.Task.Compiler
  @repo_path Path.join(Mix.Project.deps_path, "libfile")
  @magic_path Path.join(@repo_path, "/magic")
  @magdir Path.join(@magic_path, "/Magdir")
  @build_path Path.join(Mix.Project.build_path, "/majic")
  @build_magdir Path.join(@build_path, "/magic")
  @manifest Path.join(@build_path, "/majic.manifest")
  @patch_path "src/magic_patches"
  @built_path Path.join(to_string(:code.priv_dir(:majic)), "/magic.mgc")
  @shortdoc "Updates and compiles majic's embedded magic database."
  @doc """
  Uses `libfile` dependency Magdir, applies patches from `#{@patch_path}`, and builds to `#{@built_path}`.
  """

  defmodule Manifest do
    defstruct [:hash, {:patches, []}]
  end

  @impl Mix.Task.Compiler
  def clean() do
    File.rm!(@built_path)
    File.rm_rf!(@build_path)
  end

  @impl Mix.Task.Compiler
  def manifests() do
    [@manifest]
  end

  @impl Mix.Task.Compiler
  def run(_) do
    {:ok, manifest} = read_manifest()
    {:ok, sha} = get_dep_revision()
    patches = list_patches()
    File.mkdir_p!(Path.join(@build_path, "/magic"))
    if sha == nil || sha != manifest.hash || patches != manifest.patches do
      :ok = assemble_magdir()
      {:ok, patches, _err} = apply_patches()
      {:ok, _} = Majic.compile(@build_magdir)
      File.rm_rf!(@build_magdir)
      File.cp!("magic.mgc", @built_path)
      File.rm!("magic.mgc")
      manifest = %Manifest{hash: sha, patches: Enum.sort(patches)}
      File.write!(@manifest, :erlang.term_to_binary(manifest))
      Mix.shell().info("Generated magic database")
    else
      Mix.shell().info("Magic database up-to-date")
    end
    :ok
  end

  defp read_manifest() do
    with {:ok, binary} <- File.read(@manifest),
         {:term, %Manifest{} = manifest} <- {:term, :erlang.binary_to_term(binary)}
      do
      {:ok, manifest}
    else
      {:term, _} -> {:ok, %Manifest{}}
      {:error, :enoent} -> {:ok, %Manifest{}}
      error -> error
    end
  end

  defp get_dep_revision() do
    git_dir = Path.join(@repo_path, "/.git")
    case System.cmd("git", ["--git-dir=#{git_dir}", "rev-parse", "HEAD"]) do
      {rev, 0} -> {:ok, String.trim(rev)}
      _ -> {:ok, nil}
    end
  end

  defp list_patches() do
    @patch_path
    |> File.ls!()
    |> Enum.sort()
  end

  defp apply_patches() do
    patched = list_patches()
    |> Enum.map(fn(patch) ->
      path = Path.expand(Path.join(@patch_path, patch))
      case System.cmd("git", ["apply", path], cd: @build_path) do
        {_, 0} ->
          Mix.shell().info("Patched magic database: #{patch}")
          {patch, :ok}
        {error, code} ->
          Mix.shell().error("Failed to apply patch #{patch} (#{code})")
          Mix.shell().error(error)
          {patch, {:error, error}}
      end
    end)
    ok = Enum.filter(patched, fn({_, result}) -> result == :ok end) |> Enum.map(fn({name, _}) -> name end)
    err = Enum.filter(patched, fn({_, result}) -> result != :ok end) |> Enum.map(fn({name, {:error, error}})  -> {name, error} end)
    {:ok, ok, err}
  end

  defp assemble_magdir() do
    File.rm_rf!(@build_magdir)
    File.mkdir!(@build_magdir)
    File.ls!(@magdir)
    |> Enum.each(fn(file) ->
     File.cp!(Path.join(@magdir, file), Path.join(@build_magdir, file))
    end)
    :ok
  end

end
