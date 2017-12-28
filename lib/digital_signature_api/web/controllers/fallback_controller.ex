defmodule DigitalSignature.Web.FallbackController do
  @moduledoc """
  This controller should be used as `action_fallback` in rest of controllers to remove duplicated error handling.
  """
  use DigitalSignature.Web, :controller

  def call(conn, {:error, :bad_request}) do
    conn
    |> put_status(:bad_request)
    |> render(EView.Views.Error, :"400")
  end

  def call(conn, {:error, :access_denied}) do
    conn
    |> put_status(:unauthorized)
    |> render(EView.Views.Error, :"401")
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> render(EView.Views.Error, :"404")
  end

  def call(conn, nil) do
    conn
    |> put_status(:not_found)
    |> render(EView.Views.Error, :"404")
  end

  def call(conn, {:error,{:invalid_content, error_message, content}}) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(DigitalSignature.Web.InvalidContentView, "invalid.json", error_message: error_message, content: content)
  end

  def call(conn, {:error, validation_errors}) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(EView.Views.ValidationError, :"422", schema: validation_errors)
  end
end
