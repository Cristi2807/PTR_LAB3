defmodule PtrLab3 do
  use Application

  @impl true
  def start(_type, _args) do
    MainSupervisor.start_link(:ok)
  end
end
