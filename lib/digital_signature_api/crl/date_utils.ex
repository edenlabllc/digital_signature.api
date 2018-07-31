defmodule DigitalSignature.DateUtils do
  @moduledoc false

  alias Ecto.DateTime

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
            DateTime.cast(
              # XXI century, works only for 2001-2099
              {{"20" <> year, month, day}, {hour, minute, second}}
            )

          nil ->
            :error
        end
      end
    end
  end
end
