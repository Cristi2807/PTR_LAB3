defmodule QueueSupervisor do
  use Supervisor
  require Logger

  def start_link(init_arg \\ :ok) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = []

    Logger.info("#{__MODULE__} has started.")
    Supervisor.init(children, strategy: :one_for_one)
  end
end
