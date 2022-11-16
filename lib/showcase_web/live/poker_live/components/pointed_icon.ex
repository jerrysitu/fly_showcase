defmodule ShowcaseWeb.PokerLive.Components.PointedIcon do
  use Phoenix.Component
  alias Phoenix.LiveView.JS

  def icon(%{points: false, user_socket_id: user_socket_id} = assigns) do
    ~H"""
     <svg id={"red-#{user_socket_id}"} class="w-6 h-6 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
    """
  end

  def icon(%{user_socket_id: user_socket_id} = assigns) do
    ~H"""
    <svg id={"green-#{user_socket_id}"} class="w-6 h-6 text-green-600 animate-scale-in-center" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
    """
  end
end
