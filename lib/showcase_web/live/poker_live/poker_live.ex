defmodule ShowcaseWeb.PokerLive do
  # TODO: If everyone voted, show all points.

  use ShowcaseWeb, :live_view
  alias Showcase.Presence

  @possible_points [
    {"0", 0.0},
    {"0.5", 0.5},
    {"1", 1.0},
    {"2", 2.0},
    {"3", 3.0},
    {"4", 4.0},
    {"5", 5.0},
    {"8", 8.0},
    {"13", 13.0},
    {"20", 20.0}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       online_count: 0,
       user_points: 0,
       username: "",
       description: "",
       possible_points: @possible_points
     )}
  end

  @impl true
  def handle_params(%{"room" => room}, _url, socket) do
    Phoenix.PubSub.subscribe(Showcase.PubSub, room)

    room_atom = room |> String.to_atom()

    pid =
      case GenServer.whereis(room_atom) do
        nil ->
          {:ok, pid} = Showcase.Poker.start_link(room_atom)
          pid

        pid ->
          pid
      end

    participants =
      Presence.list(room)
      |> Enum.map(fn {_k, v} ->
        v[:metas] |> List.first()
      end)
      |> Enum.sort_by(& &1.username, :asc)

    reveal =
      case length(participants) do
        0 -> false
        _ -> Showcase.Poker.get_reveal(pid)
      end

    {:noreply,
     socket
     |> assign(
       room: room,
       online_count: length(participants),
       participants: participants,
       pid: pid,
       reveal: reveal
     )}
  end

  def handle_params(_params, _url, socket) do
    {:noreply,
     push_patch(socket, to: Routes.poker_path(socket, :poker, %{"room" => UUID.uuid4()}))}
  end

  @impl true
  def handle_event("join", %{"user" => %{"name" => username}}, socket) do
    %{id: socket_id, assigns: %{room: room, participants: participants}} = socket

    Presence.track(
      self(),
      room,
      socket_id,
      %{username: username, user_socket_id: socket_id, points: 0, reveal: false}
    )

    participants =
      [
        %{username: username, points: 0, user_socket_id: socket_id} | participants
      ]
      |> Enum.sort_by(& &1.username, :asc)

    {:noreply, socket |> assign(username: username, participants: participants)}
  end

  def handle_event("clear-points", _, socket) do
    %{assigns: %{room: room, pid: pid}} = socket

    Showcase.Poker.hide(pid)

    Phoenix.PubSub.broadcast(
      Showcase.PubSub,
      room,
      {__MODULE__, :clear_points, %{room: room}}
    )

    {:noreply, socket |> assign(points: 0)}
  end

  def handle_event("show-votes", _, %{assigns: %{pid: pid, room: room}} = socket) do
    Showcase.Poker.show(pid)

    Phoenix.PubSub.broadcast(
      Showcase.PubSub,
      room,
      {__MODULE__, :reveal_changed, %{}}
    )

    {:noreply, socket |> assign(reveal: true)}
  end

  def handle_event("change-points", %{"points" => points}, socket) do
    %{id: socket_id, assigns: %{room: room, username: username}} = socket

    points = Float.parse(points) |> then(fn {points, _} -> maybe_trunc(points) end)

    Presence.update(
      self(),
      room,
      socket_id,
      %{
        points: points,
        username: username,
        user_socket_id: socket_id
      }
    )

    Phoenix.PubSub.broadcast(
      Showcase.PubSub,
      room,
      {__MODULE__, :changed_points,
       %{
         room: room,
         points: points,
         username: username,
         user_socket_id: socket_id
       }}
    )

    {:noreply, socket |> assign(points: points)}
  end

  @impl true
  def handle_info(
        {__MODULE__, :changed_points,
         %{user_socket_id: user_socket_id, points: points} = _payload},
        %{id: socket_id, assigns: %{participants: participants}} = socket
      )
      when user_socket_id == socket_id do
    participant_to_update =
      participants
      |> Enum.find(&(&1.user_socket_id == user_socket_id))
      |> Map.put(:points, points)

    participants =
      participants
      |> Enum.reject(&(&1.user_socket_id == user_socket_id))
      |> then(fn x ->
        [participant_to_update, x]
        |> List.flatten()
        |> Enum.sort_by(& &1.username, :asc)
      end)

    {:noreply, socket |> assign(participants: participants)}
  end

  def handle_info({__MODULE__, :changed_points, _payload}, socket),
    do: {:noreply, socket}

  def handle_info({__MODULE__, :reveal_changed, _payload}, %{assigns: %{pid: pid}} = socket) do
    reveal = Showcase.Poker.get_reveal(pid)

    {:noreply, socket |> assign(reveal: reveal)}
  end

  def handle_info(
        {__MODULE__, :clear_points, _payload},
        %{
          id: socket_id,
          assigns: %{room: room, username: username, participants: participants, pid: pid}
        } = socket
      ) do
    Presence.update(
      self(),
      room,
      socket_id,
      %{
        points: 0,
        username: username,
        user_socket_id: socket_id
      }
    )

    reveal = Showcase.Poker.get_reveal(pid)

    participants =
      participants
      |> Enum.map(fn participant ->
        %{participant | points: 0}
      end)

    {:noreply, socket |> assign(participants: participants, points: 0, reveal: reveal)}
  end

  def handle_info(%{event: "presence_diff", topic: _msg_room}, %{assigns: %{room: room}} = socket) do
    participants =
      Presence.list(room)
      |> Enum.map(fn {_k, v} ->
        v[:metas] |> List.first()
      end)
      |> Enum.sort_by(& &1.username, :asc)

    {
      :noreply,
      socket
      |> assign(online_count: length(participants), participants: participants)
    }
  end

  defp maybe_trunc(0.5), do: 0.5
  defp maybe_trunc(float), do: float |> trunc()
end
