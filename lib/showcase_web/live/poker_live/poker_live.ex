defmodule ShowcaseWeb.PokerLive do
  # TODO: If everyone voted, show all points.

  use ShowcaseWeb, :live_view
  alias Showcase.Presence
  alias ShowcaseWeb.PokerLive.Components.PointedIcon
  alias Phoenix.LiveView.JS

  @possible_points [
    {"?", "obstain"},
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
       avg_points: 0,
       page_title: "- Planning Poker"
     )}
  end

  @impl true
  def handle_params(%{"room" => room}, _url, socket) do
    Presence.track(
      self(),
      room,
      socket.id,
      %{username: "", user_socket_id: socket.id, points: false, joined: false}
    )

    Phoenix.PubSub.subscribe(Showcase.PubSub, room)

    room_atom = room |> String.to_atom()

    if GenServer.whereis(room_atom) == nil,
      do: Showcase.PokerRoomState.start_link(room_atom)

    players =
      Presence.list(room)
      |> get_presence_players()

    reveal = Showcase.PokerRoomState.get_reveal(String.to_atom(room))

    {:noreply,
     socket
     |> assign(
       room: room,
       online_count: length(players),
       players: players,
       reveal: reveal,
       joined: false
     )}
  end

  def handle_params(_params, _url, socket) do
    {:noreply,
     push_patch(socket, to: Routes.poker_path(socket, :poker, %{"room" => UUID.uuid4()}))}
  end

  @impl true
  def handle_event("join", %{"user" => %{"name" => username}}, socket) do
    %{id: socket_id, assigns: %{room: room, players: players}} = socket

    Presence.update(
      self(),
      room,
      socket_id,
      %{username: username, user_socket_id: socket_id, points: false, joined: true}
    )

    players =
      [
        %{username: username, points: false, user_socket_id: socket_id, joined: true} | players
      ]
      |> filter_joined()
      |> Enum.filter(&(&1.points != "obstain"))
      |> Enum.sort_by(& &1.username, :asc)

    {:noreply,
     socket
     |> assign(
       username: username,
       players: players,
       joined: true,
       avg_points: calculate_avg(players)
     )}
  end

  def handle_event("clear-points", _, socket) do
    %{assigns: %{room: room}} = socket

    Showcase.PokerRoomState.hide(String.to_atom(room))

    Phoenix.PubSub.broadcast(
      Showcase.PubSub,
      room,
      {__MODULE__, :clear_points, %{room: room}}
    )

    {:noreply, socket |> assign(points: false, avg_points: 0)}
  end

  def handle_event("show-votes", _, %{assigns: %{room: room}} = socket) do
    Showcase.PokerRoomState.show(String.to_atom(room))

    Phoenix.PubSub.broadcast(
      Showcase.PubSub,
      room,
      {__MODULE__, :reveal_changed, %{}}
    )

    {:noreply, socket |> assign(reveal: true)}
  end

  def handle_event("change-points", %{"points" => "obstain"}, socket) do
    %{id: socket_id, assigns: %{room: room, username: username}} = socket

    points = "obstain"

    Presence.update(
      self(),
      room,
      socket_id,
      %{
        points: points,
        username: username,
        user_socket_id: socket_id,
        joined: true
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
         user_socket_id: socket_id,
         joined: true
       }}
    )

    {:noreply, socket |> assign(points: points)}
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
        user_socket_id: socket_id,
        joined: true
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
         user_socket_id: socket_id,
         joined: true
       }}
    )

    {:noreply, socket |> assign(points: points)}
  end

  @impl true
  def handle_info(
        {__MODULE__, :changed_points,
         %{user_socket_id: user_socket_id, points: points} = _payload},
        %{id: socket_id, assigns: %{players: players}} = socket
      )
      when user_socket_id == socket_id do
    # TODO: This is ugly
    player_to_update =
      players
      |> Enum.find(&(&1.user_socket_id == user_socket_id))
      |> Map.put(:points, points)

    players =
      players
      |> Enum.reject(&(&1.user_socket_id == user_socket_id))
      |> then(fn x ->
        [player_to_update, x]
      end)
      |> List.flatten()
      |> Enum.sort_by(& &1.username, :asc)

    {:noreply,
     socket
     |> assign(players: players)
     |> push_event("changedPoints", %{"user_socket_id" => user_socket_id, "points" => points})}
  end

  def handle_info({__MODULE__, :changed_points, _payload}, socket),
    do: {:noreply, socket}

  def handle_info(
        {__MODULE__, :reveal_changed, _payload},
        %{assigns: %{players: players, room: room}} = socket
      ) do
    reveal = Showcase.PokerRoomState.get_reveal(String.to_atom(room))

    if reveal do
      {:noreply, socket |> assign(reveal: true, avg_points: calculate_avg(players))}
    else
      {:noreply, socket}
    end
  end

  def handle_info(
        {__MODULE__, :clear_points, _payload},
        %{
          id: socket_id,
          assigns: %{room: room, username: username, players: players, joined: joined}
        } = socket
      ) do
    Presence.update(
      self(),
      room,
      socket_id,
      %{
        points: false,
        username: username,
        user_socket_id: socket_id,
        joined: joined
      }
    )

    reveal = Showcase.PokerRoomState.get_reveal(String.to_atom(room))

    players =
      players
      |> Enum.map(fn player ->
        %{player | points: false}
      end)
      |> filter_joined()
      |> Enum.sort_by(& &1.username, :asc)

    {:noreply, socket |> assign(players: players, points: false, reveal: reveal, avg_points: 0)}
  end

  def handle_info(%{event: "presence_diff"}, %{assigns: %{room: room}} = socket) do
    players =
      Presence.list(room)
      |> get_presence_players()

    {
      :noreply,
      socket
      |> assign(online_count: length(players), players: players)
    }
  end

  defp maybe_trunc(0.5), do: 0.5
  defp maybe_trunc(float), do: float |> trunc()

  def get_presence_players(presences) do
    presences
    |> Enum.map(fn {_k, v} ->
      v[:metas] |> List.first()
    end)
    |> filter_joined()
    |> Enum.sort_by(& &1.username, :asc)
  end

  defp render_points(%{reveal: true, points: false} = assigns) do
    ~H"""
    <td class="px-4 py-4 text-right text-gray-600 whitespace-nowrap">No Vote</td>
    """
  end

  defp render_points(
         %{reveal: false, points: false, user_socket_id: user_socket_id, socket_id: socket_id} =
           assigns
       )
       when user_socket_id == socket_id do
    ~H"""
    <td class="px-4 py-4 text-right w-min">
      <div class="inline-block text-gray-600 bg-gray-600 rounded-lg select-none">##</div>
    </td>
    """
  end

  defp render_points(
         %{reveal: true, points: points, user_socket_id: user_socket_id, socket_id: socket_id} =
           assigns
       )
       when user_socket_id == socket_id do
    ~H"""
    <td class="px-4 py-4 text-right text-gray-600 whitespace-nowrap"><%= points %></td>
    """
  end

  defp render_points(
         %{reveal: false, points: points, user_socket_id: user_socket_id, socket_id: socket_id} =
           assigns
       )
       when user_socket_id == socket_id do
    ~H"""
    <td class="px-4 py-4 text-right text-gray-600 whitespace-nowrap"><%= points %></td>
    """
  end

  defp render_points(%{reveal: true, points: points} = assigns) when points != false do
    ~H"""
    <td class="px-4 py-4 text-right text-gray-600 whitespace-nowrap"><%= points %></td>
    """
  end

  defp render_points(%{reveal: false} = assigns) do
    ~H"""
    <td class="px-4 py-4 text-right w-min">
      <div class="inline-block text-gray-600 bg-gray-600 rounded-lg select-none">##</div>
    </td>
    """
  end

  defp render_points(assigns) do
    ~H"""
    <td class="px-4 py-4 text-right w-min">
      <div class="inline-block text-gray-600 bg-gray-600 rounded-lg select-none">##</div>
    </td>
    """
  end

  defp calculate_avg(players) do
    # TODO: This is ugly
    with valid_players = determine_valid_players(players),
         number_of_players = length(valid_players),
         {:ok, :enough_players} <- enough_players(number_of_players),
         sum_of_points = sum_players_points(valid_players),
         {:ok, avg} <- determine_average(sum_of_points, number_of_players) do
      avg
    else
      {:error, :zero_players} -> 0.0
    end
  end

  defp determine_valid_players(players) do
    players
    |> Enum.reject(&(&1.points == "obstain"))
    |> Enum.reject(&(&1.points == false))
  end

  defp enough_players(num_of_players) when num_of_players > 0 do
    {:ok, :enough_players}
  end

  defp enough_players(_), do: {:error, :zero_players}

  defp sum_players_points(players) do
    players
    |> Enum.map(& &1.points)
    |> Enum.sum()
  end

  defp determine_average(0.0, _), do: {:ok, 0.0}
  defp determine_average(_, 0), do: {:ok, 0.0}

  defp determine_average(sum, players) do
    rem =
      try do
        rem(sum, players)
      rescue
        ArithmeticError -> false
      end

    avg =
      if rem == 0 do
        (sum / players) |> trunc()
      else
        (sum / players) |> Float.round(1)
      end

    {:ok, avg}
  end

  defp filter_joined(players), do: players |> Enum.filter(& &1.joined)
end
