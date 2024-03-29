defmodule ShowcaseWeb.PasswordGeneratorLive.PasswordModuleComponent do
  use ShowcaseWeb, :live_component
  alias Showcase.Password

  @impl true
  def mount(socket) do
    pw_length = 12
    include_number? = false
    include_special_symbol? = false

    socket =
      socket
      |> assign(include_number?: include_number?)
      |> assign(include_special_symbol?: include_special_symbol?)
      |> assign(length: pw_length)
      |> assign(show_copied_url_button: false)

    if connected?(socket) do
      {:ok, password} = Password.generate(pw_length, include_number?, include_special_symbol?)

      {
        :ok,
        socket
        |> assign(password: password)
      }
    else
      {
        :ok,
        socket
        |> assign(password: "")
      }
    end
  end

  # @impl true
  # def update(assigns, socket) do
  #   {:ok, socket |> assign(show_copied_url_button: assigns.show_copied_url_button)}
  # end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4 mt-6 rounded-lg nm-flat-slate-100-lg">
      <div class="">
        <%= text_input(:password, :input_field,
          id: "copy-password-#{@module_id}",
          class:
            "shadow-sm focus:ring-blue-500 focus:border-blue-500 block w-full sm:text-sm border-gray-300 rounded-md text-sm",
          value: @password,
          readonly: true
        ) %>
      </div>

      <div class="flex items-baseline space-x-3">
        <div
          phx-update="ignore"
          phx-hook="copyPasswordToClipboard"
          id={"copy-btn-#{@module_id}"}
          data-module-id={@module_id}
          type="button"
          class="mt-2 cursor-pointer inline-flex items-center px-2.5 py-1.5 border border-transparent text-xs font-medium rounded-full shadow-sm text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
        >
          Copy Password
        </div>
        <div
          class="flex items-baseline ml-4 h-min"
          x-data={"{ showCopied: #{@show_copied_url_button} }"}
        >
          <div
            id={"copied-tag-#{@module_id}"}
            x-show="showCopied"
            phx-update="ignore"
            x-transition:enter="transition transform duration-300"
            x-transition:enter-start="opacity-0 scale-50"
            x-transition:enter-end="opacity-100 scale-100"
            x-transition:leave="transition transform duration-300"
            x-transition:leave-start="opacity-100 scale-100"
            x-transition:leave-end="opacity-0 scale-0"
            class="inline-flex items-center px-3 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800 shadow"
          >
            Copied
          </div>
        </div>
      </div>

      <form
        phx-change="change-password-input"
        phx-target={@myself}
        phx-submit="generate-new-password"
        id={"form-#{@module_id}"}
        phx-auto-recover="ignore"
      >
        <div class="grid w-full lg:grid-cols-2 lg:gap-x-4">
          <div class="flex flex-col mt-2 text-sm">
            <div class="flex flex-col mt-3 space-y-2">
              <div class="text-sm">Password Length</div>
              <div class="flex items-center space-x-4">
                <%= number_input(:password, :length_input,
                  id: "text-input-#{@module_id}",
                  value: @length,
                  min: 6,
                  max: 64,
                  class:
                    "w-16 shadow-sm focus:ring-blue-500 focus:border-blue-500 text-xs block w-full sm:text-sm border-gray-300 rounded-md"
                ) %>
                <%= range_input(:password, :length_range,
                  id: "range-input-#{@module_id}",
                  class:
                    "w-full cursor-pointer bg-blue-300 overflow-hidden rounded-lg appearance-none",
                  value: @length,
                  phx_debounce: 0,
                  min: 6,
                  max: 64
                ) %>
              </div>
              <label class="flex items-center font-normal cursor-pointer group">
                <%= checkbox(:password, :include_number?,
                  value: @include_number?,
                  id: "checkbox-num-input-#{@module_id}",
                  class:
                    "group-hover:border-2 group-hover:border-blue-500 focus:ring-blue-500 h-4 w-4 text-blue-600 border-gray-300 rounded"
                ) %>
                <span class="ml-2 text-sm select-none group-hover:text-gray-700 lg:text-base">
                  Includes Numbers?
                </span>
              </label>

              <label class="flex items-center font-normal cursor-pointer group">
                <%= checkbox(:password, :include_special_symbol?,
                  value: @include_special_symbol?,
                  id: "checkbox-symbol-input-#{@module_id}",
                  class:
                    "group-hover:border-2 group-hover:border-blue-500 focus:ring-blue-500 h-4 w-4 text-blue-600 border-gray-300 rounded"
                ) %>
                <span class="ml-2 text-sm select-none group-hover:text-gray-700 lg:text-base">
                  Includes Special Symbols?
                </span>
              </label>
            </div>
          </div>

          <div class="place-self-end">
            <button
              type="submit"
              class="flex items-center px-2 py-2 mt-4 text-xs font-medium text-center text-white bg-blue-600 border border-transparent rounded-md shadow-sm lg:text-base lg:px-4 lg:py-2 h-min hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
            >
              Generate
              New Password
            </button>
          </div>
        </div>
      </form>
    </div>
    """
  end

  @impl true
  def handle_event("copied-password", _, socket) do
    send(self(), {:hide_copied_url_button, %{id: socket.assigns.id}})

    {:noreply, socket |> assign(show_copied_url_button: true)}
  end

  def handle_event(
        "change-password-input",
        %{
          "_target" => ["password", "length_input"],
          "password" => %{
            "length_input" => length
          }
        },
        socket
      ) do
    handle_length_change(socket, length)
  end

  def handle_event(
        "change-password-input",
        %{
          "_target" => ["password", "length_range"],
          "password" => %{
            "length_range" => length
          }
        },
        socket
      ) do
    handle_length_change(socket, length)
  end

  def handle_event(
        "change-password-input",
        %{
          "_target" => ["password", "include_number?"],
          "password" => %{
            "include_number?" => include_number?
          }
        },
        socket
      ) do
    {:ok, password} =
      Password.generate(
        socket.assigns.length,
        include_number? |> determine_boolean(),
        socket.assigns.include_special_symbol? |> determine_boolean()
      )

    {:noreply,
     socket
     |> assign(password: password)
     |> assign(include_number?: include_number?)}
  end

  def handle_event(
        "change-password-input",
        %{
          "_target" => ["password", "include_special_symbol?"],
          "password" => %{
            "include_special_symbol?" => include_special_symbol?
          }
        },
        socket
      ) do
    {:ok, password} =
      Password.generate(
        socket.assigns.length,
        socket.assigns.include_number? |> determine_boolean(),
        include_special_symbol? |> determine_boolean()
      )

    {:noreply,
     socket
     |> assign(password: password)
     |> assign(include_special_symbol?: include_special_symbol?)}
  end

  def handle_event("generate-new-password", %{}, socket) do
    {:ok, password} =
      Password.generate(
        socket.assigns.length,
        socket.assigns.include_number? |> determine_boolean(),
        socket.assigns.include_special_symbol? |> determine_boolean()
      )

    {:noreply,
     socket
     |> assign(password: password)}
  end

  defp handle_length_change(socket, length) do
    include_number? = socket.assigns.include_number? |> determine_boolean()
    include_special_symbol? = socket.assigns.include_special_symbol? |> determine_boolean()

    case Integer.parse(length) do
      :error ->
        {:noreply,
         socket
         |> put_flash(:error, "Not a number")}

      # Ensure min length
      {length, _} when length >= 6 ->
        {:ok, password} =
          Password.generate(
            length,
            include_number?,
            include_special_symbol?
          )

        {:noreply,
         socket
         |> clear_flash()
         |> assign(password: password)
         |> assign(length: length)}

      # If not min, default to min
      _ ->
        {:ok, password} =
          Password.generate(
            6,
            include_number?,
            include_special_symbol?
          )

        {:noreply,
         socket
         |> put_flash(:error, "Should be at least 6")
         |> assign(password: password)
         |> assign(length: 6)}
    end
  end

  defp determine_boolean(true), do: true
  defp determine_boolean(false), do: false
  defp determine_boolean("true"), do: true
  defp determine_boolean(_), do: false
end
