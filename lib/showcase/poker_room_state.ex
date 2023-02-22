defmodule Showcase.PokerRoomState do
  use GenServer

  alias Showcase.Presence

  def start_link(room) do
    {:ok, pid} = GenServer.start_link(__MODULE__, room, name: room)
    IO.puts("Starting room: #{room}")
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

  def terminate(name) do
    GenServer.call(name, :terminate)
  end

  @impl true
  def init(room) do
    Process.flag(:trap_exit, true)
    room = room |> Atom.to_string()
    Phoenix.PubSub.subscribe(Showcase.PubSub, room)

    {:ok, %{reveal: false, room: room}}
  end

  @impl true
  def handle_info(
        %{topic: msg_room, event: "presence_diff", payload: _payload},
        %{room: room} = state
      )
      when msg_room == room do
    if Presence.list(room) |> Kernel.map_size() == 0 do
      # Closing due to empty room
      {:stop, :normal, %{state | reveal: false}}
    else
      {:noreply, state}
    end
  end

  # Fallback for handling anything else and return state
  def handle_info(_payload, state) do
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

  def handle_call(:terminate, _from, state) do
    {:stop, :shutdown, state}
  end

  @impl true
  def terminate(_reason, _state) do
    IO.puts("Shutting down due to empty room")

    {:shutdown, :empty_room}
  end
end
