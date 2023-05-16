defmodule Queue do
  use GenServer
  require Logger

  def start_link(state) do
    Logger.info("Queue.#{state.username} starting")
    GenServer.start_link(__MODULE__, state, name: :"#{__MODULE__}.#{state.username}")
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call(:save, _from, state) do
    state_saved = state

    topics = MapSet.to_list(state_saved.topics)
    state_saved = state_saved |> Map.put(:topics, topics)
    state_saved = state_saved |> Map.put(:sockets, [])

    {:ok, json} = Poison.encode(state_saved)

    File.write("./queues/queue_#{state.username}.json", json)
    IO.puts("Data for user #{state.username} successfully saved.")

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:add_socket, socket}, _from, state) do
    case state.unread_msgs do
      [] ->
        nil

      _ ->
        :gen_tcp.send(socket, "\r\n\r\n New Unacknowledged Messages: \r\n")
    end

    state.unread_msgs
    |> Enum.each(fn message -> :gen_tcp.send(socket, message) end)

    case state.unread_msgs do
      [] ->
        nil

      _ ->
        :gen_tcp.send(socket, "------------------------------------\r\n\r\n")
    end

    sockets = state.sockets ++ [socket]
    {:reply, :ok, state |> Map.put(:sockets, sockets)}
  end

  @impl true
  def handle_call({:acknowledge, uuid}, _from, state) do
    unread =
      state.unread_msgs
      |> Enum.filter(fn msg -> !String.contains?(msg, uuid) end)

    {:reply, :ok, state |> Map.put(:unread_msgs, unread)}
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
    uuid = generate()

    case state.topics |> Enum.member?(topic) do
      true ->
        sockets =
          state.sockets
          |> Enum.reduce([], fn socket, acc ->
            list =
              case :gen_tcp.send(
                     socket,
                     "\r\n#{DateTime.to_string(DateTime.utc_now())} [#{topic}] #{message}  !#{uuid}!\r\n"
                   ) do
                :ok -> [socket]
                {:error, _} -> []
              end

            acc ++ list
          end)

        unread =
          state.unread_msgs ++
            ["\r\n#{DateTime.to_string(DateTime.utc_now())} [#{topic}] #{message}  !#{uuid}!\r\n"]

        {:noreply, state |> Map.put(:sockets, sockets) |> Map.put(:unread_msgs, unread)}

      false ->
        {:noreply, state}
    end
  end

  def add_socket(server, socket) do
    :ok = GenServer.call(server, {:add_socket, socket})
    :ok = GenServer.call(server, :save)
  end

  def add_topic(server, topic) do
    :ok = GenServer.call(server, {:add_topic, topic})
    :ok = GenServer.call(server, :save)
  end

  def remove_topic(server, topic) do
    :ok = GenServer.call(server, {:remove_topic, topic})
    :ok = GenServer.call(server, :save)
  end

  def post_message(server, topic, message) do
    GenServer.cast(server, {:post_message, topic, message})
    :ok = GenServer.call(server, :save)
  end

  def acknowledge_message(server, uuid) do
    :ok = GenServer.call(server, {:acknowledge, uuid})
    :ok = GenServer.call(server, :save)
  end

  def get_name(username) do
    :"#{__MODULE__}.#{username}"
  end

  defp generate() do
    random_bytes = :crypto.strong_rand_bytes(16)

    <<a::8, b::8, c::8, d::8, e::8, f::8, g::8, h::8, i::8, j::8, k::8, l::8, m::8, n::8, o::8,
      p::8>> = random_bytes

    <<a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p>>
    |> Base.encode16(case: :lower)
    |> String.slice(0..31)
    |> String.upcase()
  end
end
