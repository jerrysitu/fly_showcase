defmodule Showcase.PokerRoomState do
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
      # TODO: close room!
      # IO.puts("Closing room!")
      # {:stop, :room_empty, %{state | reveal: false}}

      {:noreply, %{state | reveal: false}}
    else
      {:noreply, state}
    end
  end

  def handle_info(
        %{topic: msg_room, event: "presence_diff", payload: %{joins: joins}},
        %{room: room} = state
      ) do
    msg_room |> IO.inspect(label: "msg_room!!")
    room |> IO.inspect(label: "room!!")

    {:noreply, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast({:show, _}, state) do
    {:noreply, %{state | reveal: true}}
  end

  def handle_cast({:hide, _}, state) do
    {:noreply, %{state | reveal: false}}
  end

  @impl true
  def handle_call(:get_reveal, _from, state) do
    %{reveal: reveal} = state

    {:reply, reveal, state}
  end
end

# room = "5cc90d46-796c-4239-a82f-f498c3892da4"
# room_atom = room |> String.to_atom()
# pid = GenServer.whereis(room_atom)
# Showcase.PokerRoomState.get_reveal(pid) |> IO.inspect(label: "Reveal:")
# Showcase.Presence.list(room)
