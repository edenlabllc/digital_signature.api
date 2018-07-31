defmodule DigitalSignature.DateUtils do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      def convert_date(date) do
        case Regex.named_captures(
               ~r/(?<year>\d{2})(?<month>\d{2})(?<day>\d{2})(?<hour>\d{2})(?<minute>\d{2})(?<second>\d{2})Z/,
               to_string(date)
             ) do
          %{
            "day" => day,
            "hour" => hour,
            "minute" => minute,
            "month" => month,
            "second" => second,
            "year" => year
          } = utc_date ->
            with {:ok, ecto_datetime} <-
                   Ecto.DateTime.cast(
                     # XXI century, works only for 2001-2099
                     {{"20" <> year, month, day}, {hour, minute, second}}
                   ) do
              dt =
                ecto_datetime |> Ecto.DateTime.to_erl() |> NaiveDateTime.from_erl!() |> DateTime.from_naive!("Etc/UTC")

              {:ok, dt}
            else
              _ -> :error
            end

          nil ->
            :error
        end
      end
    end
  end
end
