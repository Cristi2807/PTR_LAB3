defmodule ProducerConnHandler do
  require Logger

  def serve(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, data} ->
        Logger.info("Producer Data Received")
        handle_command(socket, data)
        serve(socket)

      {:error, :closed} ->
        Logger.info("Producer Connection Closed")
    end
  end

  defp handle_command(socket, string) do
    string =
      string
      |> String.trim()
      |> String.split()

    case Enum.at(string, 0) do
      "publish" ->
        topic = Enum.at(string, 1)

        message =
          string
          |> Enum.drop(2)
          |> Enum.join(" ")

        handle_publish(socket, topic, message)

      "publish_json" ->
        json =
          string
          |> Enum.drop(1)
          |> Enum.join(" ")

        handle_publish_json(socket, json)

      _ ->
        handle_unknown_command(socket, string)
    end
  end

  defp handle_publish(socket, topic, msg) do
    Supervisor.which_children(QueueSupervisor)
    |> Enum.map(fn {_, pid, _, _} ->
      Queue.post_message(pid, topic, msg)
    end)

    :gen_tcp.send(socket, "Message '#{msg}' successfully published in topic '#{topic}'.\r\n")
  end

  defp handle_publish_json(socket, json) do
    case Poison.decode(json) do
      {:ok, value} ->
        Supervisor.which_children(QueueSupervisor)
        |> Enum.map(fn {_, pid, _, _} ->
          Queue.post_message(pid, value["topic"], value["message"])
        end)

        :gen_tcp.send(socket, "JSON successfully published.\r\n")

      {:error, _} ->
        DeadLetter.add_msg(json)
        :gen_tcp.send(socket, "JSON parsing error encountered. Message not posted.\r\n")
    end
  end

  defp handle_unknown_command(socket, string) do
    :gen_tcp.send(socket, string ++ " is not a valid command! \r\n")
  end
end
