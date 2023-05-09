defmodule ConsumerConnHandler do
  require Logger

  def serve(socket, state \\ %{current_user: nil}) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, data} ->
        Logger.info("Consumer Data Received")
        state = handle_command(socket, data, state)
        serve(socket, state)

      {:error, :closed} ->
        Logger.info("Consumer Connection Closed")
    end
  end

  defp handle_command(socket, string, state) do
    string =
      string
      |> String.trim()
      |> String.split()

    case string do
      ["user", username] -> handle_username(socket, state, username)
      ["subscribe", topic] -> handle_subscribe(socket, state, topic)
      ["unsubscribe", topic] -> handle_unsubscribe(socket, state, topic)
      _ -> handle_unknown_command(socket, string, state)
    end
  end

  defp handle_username(socket, state, username) do
    state =
      case state.current_user do
        nil ->
          case Supervisor.start_child(QueueSupervisor, %{
                 id: :"#{username}",
                 start: {Queue, :start_link, [username]}
               }) do
            {:ok, _pid} ->
              Logger.info("Queue for user #{username} has been created")

            {:error, {:already_started, _pid}} ->
              Logger.info("Queue for user #{username} exists.")
          end

          :gen_tcp.send(socket, "Acting as #{username}\r\n")
          %{current_user: username}

        val ->
          :gen_tcp.send(socket, "Cannot change user.\r\n")
          %{current_user: val}
      end

    Queue.get_name(username)
    |> Queue.add_socket(socket)

    state
  end

  defp handle_subscribe(socket, state, topic) do
    case state.current_user do
      nil ->
        :gen_tcp.send(socket, "Act as user before subscribing to a topic.\r\n")

      val ->
        Queue.get_name(val)
        |> Queue.add_topic(topic)

        :gen_tcp.send(socket, "Successfully subscribed to '#{topic}' topic.\r\n")
    end

    state
  end

  defp handle_unsubscribe(socket, state, topic) do
    case state.current_user do
      nil ->
        :gen_tcp.send(socket, "Act as user before unsubscribing to a topic.\r\n")

      val ->
        Queue.get_name(val)
        |> Queue.remove_topic(topic)

        :gen_tcp.send(socket, "Successfully unsubscribed from '#{topic}' topic.\r\n")
    end

    state
  end

  defp handle_unknown_command(socket, string, state) do
    :gen_tcp.send(socket, string ++ " is not a valid command! \r\n")
    state
  end
end
