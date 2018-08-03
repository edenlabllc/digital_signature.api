defmodule DigitalSignature.Factory do
  @moduledoc false
  alias DigitalSignature.Crl
  alias DigitalSignature.RevokedSN

  use ExMachina.Ecto, repo: DigitalSignature.Repo

  def crl_factory do
    %Crl{
      url: "example.com",
      next_update: NaiveDateTime.add(NaiveDateTime.utc_now(), 1, :day)
    }
  end

  def revoked_factory do
    %RevokedSN{
      url: "example.com",
      serial_number: sequence("1092827363459766")
    }
  end
end
