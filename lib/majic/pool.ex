defmodule Majic.Pool do
  @behaviour NimblePool
  @moduledoc "Pool of `Majic.Server`"

  @type name :: atom()
  @type option :: {:pool_timeout, timeout()} | {:timeout, timeout()}

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def start_link(options) do
    {pool_size, options} = Keyword.pop(options, :pool_size, System.schedulers_online())
    NimblePool.start_link(worker: {__MODULE__, options}, pool_size: pool_size)
  end

  @spec perform(name(), Majic.target(), [option()]) :: Majic.result()
  def perform(pool, path, opts \\ []) do
    pool_timeout = Keyword.get(opts, :pool_timeout, Majic.Config.default_process_timeout())
    timeout = Keyword.get(opts, :timeout, Majic.Config.default_process_timeout())

    NimblePool.checkout!(
      pool,
      :checkout,
      fn _, server ->
        {Majic.Server.perform(server, path, timeout), server}
      end,
      pool_timeout
    )
  end

  @impl NimblePool
  def init_pool(options) do
    {name, options} =
      case Keyword.pop(options, :name) do
        {name, options} when is_atom(name) -> {name, options}
        {nil, options} -> {__MODULE__, options}
        {_, options} -> {nil, options}
      end

    if name, do: Process.register(self(), name)
    {:ok, options}
  end

  @impl NimblePool
  def init_worker(options) do
    {:ok, server} = Majic.Server.start_link(options || [])
    {:ok, server, options}
  end

  @impl NimblePool
  def handle_checkout(:checkout, _from, server, pool) do
    {:ok, server, server, pool}
  end

  @impl NimblePool
  def handle_checkin(_, _, server, pool) do
    {:ok, server, pool}
  end

  @impl NimblePool
  def terminate_worker(_reason, _worker, state) do
    {:ok, state}
  end
end
