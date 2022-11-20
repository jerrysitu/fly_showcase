defmodule ShowcaseWeb.CalendarLive do
  use ShowcaseWeb, :live_view
  use Timex
  alias Showcase.Normalizer
  alias ShowcaseWeb.CalendarDayComponent

  @impl true
  def mount(_params, session, socket) do
    IO.inspect(label: "mounttt")

    user_timezone = Normalizer.get_timezone(socket, session)
    current_date = Timex.now() |> Timex.shift(hours: user_timezone)
    day_names = [7, 1, 2, 3, 4, 5, 6] |> Enum.map(&Timex.day_shortname/1)

    offset = 0

    {:ok,
     socket
     |> assign(
       offset: offset,
       current_date: current_date,
       day_names: day_names,
       month_tables: month_tables(current_date, offset, user_timezone),
       user_timezone: user_timezone
     )}
  end

  @impl true
  def handle_params(%{"offset" => offset}, _url, socket) do
    offset = offset |> String.to_integer()

    current_date = Timex.shift(socket.assigns.current_date, months: offset)

    month_tables = month_tables(current_date, offset, socket.assigns.user_timezone)

    {:noreply, socket |> assign(month_tables: month_tables, offset: offset)}
  end

  def handle_params(_params, _url, socket) do
    offset = 0

    current_date = Timex.shift(socket.assigns.current_date, months: offset)

    month_tables = month_tables(current_date, offset, socket.assigns.user_timezone)

    {:noreply, socket |> assign(month_tables: month_tables, offset: offset)}
  end

  @impl true
  def handle_event("change-month", %{"offset" => offset}, socket) do
    offset = offset |> String.to_integer()

    current_date = Timex.shift(socket.assigns.current_date, months: offset)

    month_tables = month_tables(current_date, offset, socket.assigns.user_timezone)

    {:noreply, socket |> assign(month_tables: month_tables, offset: offset)}
  end

  defp month_tables(date, offset, user_timezone) do
    offset..(offset + 1)
    |> Enum.map(fn offset ->
      date = date |> Timex.shift(hours: user_timezone) |> Timex.shift(months: offset)
      days = days(date)

      %{date: date, days: days}
    end)
  end

  defp days(date) do
    first =
      date
      |> Timex.beginning_of_month()
      |> Timex.beginning_of_week(:sun)

    last =
      date
      |> Timex.end_of_month()
      |> Timex.end_of_week(:sun)

    Interval.new(from: first, until: last)
    |> Enum.map(& &1)
  end
end
