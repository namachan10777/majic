defmodule Mix.Tasks.Compile.Majic do
  use Mix.Task.Compiler
  @repo_path Path.join(Mix.Project.deps_path(), "file")
  @build_path Path.join(Mix.Project.build_path(), "/majic")
  @manifest Path.join(Mix.Project.manifest_path(), "/compile.majic")
  @patch_path "src/magic_patches"
  @built_mgc_path Path.join(to_string(:code.priv_dir(:majic)), "/magic.mgc")
  @built_magic_path Path.join(to_string(:code.priv_dir(:majic)), "/magic")

  @magic_path Path.join(@repo_path, "/magic")
  @magdir Path.join(@magic_path, "/Magdir")
  @build_magdir Path.join(@build_path, "/magic")
  @shortdoc "Updates and compiles majic's embedded magic database."
  @moduledoc """
  Uses `libfile` dependency Magdir, applies patches from `#{@patch_path}`, and builds to `#{
    @built_mgc_path
  }`.

  Unlike most Mix compile tasks, this task can be called at runtime from `Majic.Application` to ensure that the built-in
  compiled magic database is working on the current system.
  """

  defmodule Manifest do
    @moduledoc false
    defstruct [:hash, {:patches, []}]
  end

  @impl Mix.Task.Compiler
  def clean do
    File.rm(@built_mgc_path)
    File.rm(@built_magic_path)
    File.rm_rf(@build_path)
  end

  @impl Mix.Task.Compiler
  def manifests do
    [@manifest]
  end

  @impl Mix.Task.Compiler
  def run(_) do
    {:ok, manifest} = read_manifest()
    {:ok, sha} = get_dep_revision()
    patches = list_patches()
    File.mkdir_p!(@build_magdir)

    if !File.exists?(@built_mgc_path) || !File.exists?(@built_magic_path) || sha == nil ||
         sha != manifest.hash || patches != manifest.patches do
      :ok = assemble_magdir()
      {:ok, patches, _err} = apply_patches()
      :ok = assemble_magic(@built_magic_path)
      case Majic.compile(@build_magdir) do
        {:ok, _} ->
          File.cp!("magic.mgc", @built_mgc_path)
          File.rm!("magic.mgc")
          manifest = %Manifest{hash: sha, patches: Enum.sort(patches)}
          File.write!(@manifest, :erlang.term_to_binary(manifest))
          Mix.shell().info("Majic: Generated magic database")
          :ok
        {:error, _} ->
          Mix.shell().error("Majic: Compilation of database failed.")
      end
    end

    :ok
  end

  defp read_manifest do
    with {:ok, binary} <- File.read(@manifest),
         {:term, %Manifest{} = manifest} <- {:term, :erlang.binary_to_term(binary)} do
      {:ok, manifest}
    else
      {:term, _} -> {:ok, %Manifest{}}
      {:error, :enoent} -> {:ok, %Manifest{}}
      error -> error
    end
  end

  defp get_dep_revision do
    git_dir = Path.join(@repo_path, "/.git")

    case System.cmd("git", ["--git-dir=#{git_dir}", "rev-parse", "HEAD"]) do
      {rev, 0} -> {:ok, String.trim(rev)}
      _ -> {:ok, nil}
    end
  end

  defp list_patches do
    @patch_path
    |> File.ls!()
    |> Enum.filter(fn file ->
      Path.extname(file) == ".patch"
    end)
    |> Enum.sort()
  end

  defp apply_patches do
    patched =
      list_patches()
      |> Enum.map(fn patch ->
        path = Path.expand(Path.join(@patch_path, patch))

        # We rewrite paths in patch because we're not applying the patch from repository root, but in a temporary
        # build folder that is just the Magdir.
        case System.cmd("git", ["apply", "-p3", "--directory=magic/", path], cd: @build_path) do
          {_, 0} ->
            Mix.shell().info("Majic: Patched magic database: #{patch}")
            {patch, :ok}

          {error, code} ->
            Mix.shell().error("Majic: Failed to apply patch #{patch} (#{code})")
            Mix.shell().error(error)
            {patch, {:error, error}}
        end
      end)

    ok =
      Enum.filter(patched, fn {_, result} -> result == :ok end)
      |> Enum.map(fn {name, _} -> name end)

    err =
      Enum.filter(patched, fn {_, result} -> result != :ok end)
      |> Enum.map(fn {name, {:error, error}} -> {name, error} end)

    {:ok, ok, err}
  end

  defp assemble_magdir do
    File.rm_rf!(@build_magdir)
    File.mkdir!(@build_magdir)

    File.ls!(@magdir)
    |> Enum.each(fn file ->
      File.cp!(Path.join(@magdir, file), Path.join(@build_magdir, file))
    end)

    :ok
  end

  defp assemble_magic(destination) do
    contents =
      File.ls!(@build_magdir)
      |> Enum.reduce(<<>>, fn file, acc ->
        content = File.read!(Path.join(@build_magdir, file))
        <<acc::binary, content::binary>>
      end)

    File.write!(destination, contents)
    :ok
  end
end
