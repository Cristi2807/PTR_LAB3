defmodule MainSupervisor do
  use Supervisor

  def start_link(init_arg \\ :ok) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {QueueSupervisor, []},
      {Task.Supervisor, name: ConsumerConnTaskSupervisor},
      {ConsumerConnAccepter, 4040},
      {Task.Supervisor, name: ProducerConnTaskSupervisor},
      {ProducerConnAccepter, 8080}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
