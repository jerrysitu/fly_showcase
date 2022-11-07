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
    {"5", 5.0},
    {"8", 8.0},
    {"13", 13.0},
    {"20", 20.0},
    {"40", 40.0},
    {"100", 100.0}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       joined: false,
       online_count: 0,
       user_points: false,
       username: "",
       description: "",
       possible_points: @possible_points,
       avg_points: 0
     )}
  end

  @impl true
  def handle_params(%{"room" => room}, _url, socket) do
    Phoenix.PubSub.subscribe(Showcase.PubSub, room)

    room_atom = room |> String.to_atom()

    pid =
      case GenServer.whereis(room_atom) do
        nil ->
          {:ok, pid} = Showcase.PokerRoomState.start_link(room_atom)
          pid

        pid ->
          pid
      end

    participants =
      Presence.list(room)
      |> get_presence_participants()

    reveal = Showcase.PokerRoomState.get_reveal(pid)

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
      %{username: username, user_socket_id: socket_id, points: false, reveal: false}
    )

    participants =
      [
        %{username: username, points: false, user_socket_id: socket_id} | participants
      ]
      |> Enum.sort_by(& &1.username, :asc)

    avg_points = calculate_avg(participants)

    {:noreply,
     socket
     |> assign(
       username: username,
       participants: participants,
       joined: true,
       avg_points: avg_points
     )}
  end

  def handle_event("clear-points", _, socket) do
    %{assigns: %{room: room, pid: pid}} = socket

    Showcase.PokerRoomState.hide(pid)

    Phoenix.PubSub.broadcast(
      Showcase.PubSub,
      room,
      {__MODULE__, :clear_points, %{room: room}}
    )

    {:noreply, socket |> assign(points: false, avg_points: 0)}
  end

  def handle_event("show-votes", _, %{assigns: %{pid: pid, room: room}} = socket) do
    Showcase.PokerRoomState.show(pid)

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

  def handle_info(
        {__MODULE__, :reveal_changed, _payload},
        %{assigns: %{pid: pid, participants: participants}} = socket
      ) do
    reveal = Showcase.PokerRoomState.get_reveal(pid)

    if reveal do
      avg_points = calculate_avg(participants)

      {:noreply, socket |> assign(reveal: true, avg_points: avg_points)}
    else
      {:noreply, socket}
    end
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
        points: false,
        username: username,
        user_socket_id: socket_id
      }
    )

    reveal = Showcase.PokerRoomState.get_reveal(pid)

    participants =
      participants
      |> Enum.map(fn participant ->
        %{participant | points: false}
      end)

    {:noreply,
     socket |> assign(participants: participants, points: false, reveal: reveal, avg_points: 0)}
  end

  def handle_info(%{event: "presence_diff", topic: _msg_room}, %{assigns: %{room: room}} = socket) do
    participants =
      Presence.list(room)
      |> get_presence_participants()

    {
      :noreply,
      socket
      |> assign(online_count: length(participants), participants: participants)
    }
  end

  defp maybe_trunc(0.5), do: 0.5
  defp maybe_trunc(float), do: float |> trunc()

  def get_presence_participants(presences) do
    presences
    |> Enum.map(fn {_k, v} ->
      v[:metas] |> List.first()
    end)
    |> Enum.sort_by(& &1.username, :asc)
  end

  defp render_points(
         %{points: points, user_socket_id: user_socket_id, socket_id: socket_id} = assigns
       )
       when user_socket_id == socket_id and points == false do
    ~H"""
    <td class="px-3 py-4 text-right w-min">
      <div class="inline-block text-gray-600 bg-gray-600 rounded-lg">00</div>
    </td>
    """
  end

  defp render_points(
         %{points: points, user_socket_id: user_socket_id, socket_id: socket_id} = assigns
       )
       when user_socket_id == socket_id and points != false do
    ~H"""
    <td class="px-3 py-4 text-sm text-right text-gray-500 whitespace-nowrap"><%= points %></td>
    """
  end

  defp render_points(%{reveal: true, points: points} = assigns) do
    ~H"""
    <td class="px-3 py-4 text-sm text-right text-gray-500 whitespace-nowrap"><%= points %></td>
    """
  end

  defp render_points(%{reveal: false} = assigns) do
    ~H"""
    <td class="px-3 py-4 text-right w-min">
      <div class="inline-block text-gray-600 bg-gray-600 rounded-lg">00</div>
    </td>
    """
  end

  defp calculate_avg(participants) do
    0

    # participants |> IO.inspect(label: "participants!!")

    # number_of_participants =
    #   determine_valid_participants(participants)
    #   |> IO.inspect(label: "number_of_participants!!")

    # with {:ok, :enough_participants} <- enough_participants(number_of_participants),
    #      sum_of_points = sum_participants_points(participants),
    #      {:ok, avg} <- determine_average(number_of_participants, sum_of_points) do
    #   avg
    # else
    #   {:error, :zero_participants} -> 0.0
    # end

    # participants_with_points =
    #   participants
    #   |> Enum.reject(&(&1 == false))

    # sum =
    #   participants_with_points
    #   |> Enum.map(& &1.points)
    #   |> Enum.sum()

    # avg =
    #   case sum do
    #     0.0 -> 0.0
    #     sum -> (sum / length(participants_with_points)) |> Float.round(1)
    #   end

    # if is_integer(avg) do
    #   trunc(avg)
    # else
    #   avg
    # end
  end

  defp determine_valid_participants(participants) do
    participants
    |> Enum.reject(&(&1.points == false))
    |> length()
  end

  defp enough_participants(num_of_participants) when num_of_participants > 0 do
    {:ok, :enough_participants}
  end

  defp enough_participants(_), do: {:error, :zero_participants}

  defp sum_participants_points(participants) do
    participants
    |> Enum.map(& &1.points)
    |> Enum.sum()
  end

  defp determine_average(0.0, _), do: 0.0
  defp determine_average(_, 0.0), do: 0.0

  defp determine_average(number_of_participants, sum_of_points) do
    (sum_of_points / number_of_participants) |> Float.round(1)
  end
end
