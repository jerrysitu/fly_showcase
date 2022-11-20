defmodule ShowcaseWeb.CalendarDayComponent do
  use Phoenix.LiveComponent
  use Timex

  @impl true
  def render(assigns) do
    cond do
      today?(assigns) ->
        ~H"""
        <button type="button" class="relative bg-white py-1.5 text-gray-900 hover:bg-gray-100 focus:z-10">
          <time phx-click="pick-date" phx-value-date={Timex.format!(@day, "%Y-%m-%d", :strftime)} datetime={Timex.format!(@day, "%Y-%m-%d", :strftime)} class="flex items-center justify-center mx-auto font-semibold text-white bg-indigo-600 rounded-full h-7 w-7">
            <%= Timex.format!(@day, "%d", :strftime) %>
          </time>
        </button>
        """

      other_month?(assigns) ->
        ~H"""
        <div class="relative bg-gray-50 py-1.5 text-gray-400 select-none">
          <time datetime={Timex.format!(@day, "%Y-%m-%d", :strftime)} class="flex items-center justify-center mx-auto rounded-full h-7 w-7">
            <%= Timex.format!(@day, "%d", :strftime) %>
          </time>
        </div>
        """

      true ->
        ~H"""
        <button type="button" class="relative bg-white py-1.5 text-gray-900 hover:bg-gray-100 focus:z-10">
          <time phx-click="pick-date" phx-value-date={Timex.format!(@day, "%Y-%m-%d", :strftime)} datetime={Timex.format!(@day, "%Y-%m-%d", :strftime)} class="flex items-center justify-center mx-auto rounded-full h-7 w-7">
            <%= Timex.format!(@day, "%d", :strftime) %>
          </time>
        </button>
        """
    end
  end

  @impl true
  def handle_event("pick-date", %{"date" => date}, socket) do
    current_date = Timex.parse!(date, "{YYYY}-{0M}-{D}")

    assigns = [
      current_date: current_date
    ]

    {:noreply, assign(socket, assigns)}
  end

  defp today?(assigns) do
    Map.take(assigns.day, [:year, :month, :day]) ==
      Timex.now() |> Map.take([:year, :month, :day])
  end

  defp other_month?(assigns) do
    Map.take(assigns.day, [:year, :month]) != Map.take(assigns.current_date, [:year, :month])
  end
end
