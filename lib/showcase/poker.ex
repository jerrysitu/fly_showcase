defmodule Showcase.Poker do
  use GenServer

  def start_link(room) do
    {:ok, pid} = GenServer.start_link(__MODULE__, room, name: room)

    {:ok, pid}
  end

  def show(name) do
    GenServer.cast(name, {:show, nil})
  end

  def hide(name) do
    GenServer.cast(name, {:hide, nil})
  end

  def get_reveal(name) do
    GenServer.call(name, :get_reveal)
  end

  @impl true
  def init(room) do
    room |> IO.inspect(label: "roommmm")
    room = room |> Atom.to_string()
    Phoenix.PubSub.subscribe(Showcase.PubSub, room)

    {:ok, %{reveal: false, room: room}}
  end

  @impl true
  def handle_info(
        %{topic: msg_room, event: "presence_diff", payload: %{joins: joins}},
        %{room: room} = state
      )
      when msg_room == room do
    if joins |> Kernel.map_size() == 0 do
      IO.puts("Closing room!")
      {:stop, "room empty", nil}
    end

    {:noreply, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast({:show, _}, state) do
    {:noreply, state |> Map.put(:reveal, true)}
  end

  def handle_cast({:hide, _}, state) do
    {:noreply, state |> Map.put(:reveal, false)}
  end

  @impl true
  def handle_call(:get_reveal, _from, state) do
    %{reveal: reveal} = state

    {:reply, reveal, state}
  end
end
