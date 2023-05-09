defmodule Queue do
  use GenServer

  def start_link(username) do
    IO.puts("Queue.#{username} starting")
    GenServer.start_link(__MODULE__, username, name: :"#{__MODULE__}.#{username}")
  end

  @impl true
  def init(_init_arg) do
    {:ok, %{topics: MapSet.new(), sockets: []}}
  end

  @impl true
  def handle_call({:add_socket, socket}, _from, state) do
    sockets = state.sockets ++ [socket]
    {:reply, :ok, state |> Map.put(:sockets, sockets)}
  end

  @impl true
  def handle_call({:add_topic, topic}, _from, state) do
    topics = state.topics |> MapSet.put(topic)
    {:reply, :ok, state |> Map.put(:topics, topics)}
  end

  @impl true
  def handle_call({:remove_topic, topic}, _from, state) do
    topics = state.topics |> MapSet.delete(topic)
    {:reply, :ok, state |> Map.put(:topics, topics)}
  end

  @impl true
  def handle_cast({:post_message, topic, message}, state) do
    case state.topics |> Enum.member?(topic) do
      true ->
        sockets =
          state.sockets
          |> Enum.reduce([], fn socket, acc ->
            list =
              case :gen_tcp.send(
                     socket,
                     "\r\n#{DateTime.to_string(DateTime.utc_now())} [#{topic}] #{message}\r\n"
                   ) do
                :ok -> [socket]
                {:error, _} -> []
              end

            acc ++ list
          end)

        {:noreply, state |> Map.put(:sockets, sockets)}

      false ->
        {:noreply, state}
    end
  end

  def add_socket(server, socket) do
    :ok = GenServer.call(server, {:add_socket, socket})
  end

  def add_topic(server, topic) do
    :ok = GenServer.call(server, {:add_topic, topic})
  end

  def remove_topic(server, topic) do
    :ok = GenServer.call(server, {:remove_topic, topic})
  end

  def post_message(server, topic, message) do
    GenServer.cast(server, {:post_message, topic, message})
  end

  def get_name(username) do
    :"#{__MODULE__}.#{username}"
  end
end
