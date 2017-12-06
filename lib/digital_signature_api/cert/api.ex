defmodule DigitalSignature.Cert.API do
  @moduledoc false

  import Ecto.{Query, Changeset}, warn: false
  alias DigitalSignature.Repo
  alias DigitalSignature.Cert

  def get_certs_map do
    query = from p in Cert,
      where: p.type in ["root", "tsp"] and p.active,
      left_join: c in Cert,
      on: c.parent == p.id and c.type == "ocsp" and c.active,
      select: {p.type, p.data, c.data}

    query
    |> Repo.all()
    |> Enum.reduce(%{general: [], tsp: []}, &process_cert(&1, &2))
  end

  defp process_cert({"root", rootCert, ocspCert}, %{general: general} = map) do
    new_root = %{root: prepare_cert_data(rootCert), ocsp: prepare_cert_data(ocspCert)}

    Map.put(map, :general, [new_root | general])
  end
  defp process_cert({"tsp", tspCert, _}, %{tsp: tsp} = map) do
    Map.put(map, :tsp, [prepare_cert_data(tspCert) | tsp])
  end

  defp prepare_cert_data(nil), do: nil
  defp prepare_cert_data(data), do: :erlang.binary_to_list(data)
end
