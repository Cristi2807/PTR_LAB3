defmodule DeadLetter do
  use GenServer
  require Logger

  def start_link(init_arg \\ :ok) do
    Logger.info("DeadLetterChannel starting")
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    {:ok, []}
  end

  @impl true
  def handle_call({:add_message, json}, _from, state) do
    state = state ++ [json]
    IO.puts("New message in dead letter channel : #{json}")
    {:reply, :ok, state}
  end

  def add_msg(json) do
    :ok = GenServer.call(__MODULE__, {:add_message, json})
  end
end
