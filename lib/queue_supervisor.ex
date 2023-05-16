defmodule QueueSupervisor do
  use Supervisor
  require Logger

  def start_link(init_arg \\ :ok) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children =
      get_file_names()
      |> Enum.reduce([], fn file_name, acc ->
        {:ok, val} = File.read(file_name)
        {:ok, map} = Poison.decode(val)

        map =
          map
          |> Map.put(:topics, map["topics"] |> MapSet.new())
          |> Map.put(:username, map["username"])
          |> Map.put(:unread_msgs, map["unread_msgs"])
          |> Map.put(:sockets, [])
          |> Map.delete("topics")
          |> Map.delete("username")
          |> Map.delete("unread_msgs")
          |> Map.delete("sockets")

        acc ++
          [
            %{
              id: :"#{map.username}",
              start: {Queue, :start_link, [map]}
            }
          ]
      end)

    Logger.info("#{__MODULE__} has started.")
    Supervisor.init(children, strategy: :one_for_one)
  end

  defp get_file_names() do
    Path.wildcard("./queues/queue_*.json")
    |> Enum.map(fn string -> "./" <> string end)
  end
end
