defmodule DigitalSignature.NifServiceBehaviour do
  @moduledoc false

  @callback ocsp_response(params :: map, timeot :: integer) :: {:ok, result :: term} | {:error, reason :: term}
end
