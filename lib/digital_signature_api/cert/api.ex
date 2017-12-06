defmodule DigitalSignature.Cert.API do
  @moduledoc false

  import Ecto.{Query, Changeset}, warn: false
  alias DigitalSignature.Repo
  alias DigitalSignature.Cert

  def get_certs_map do
    query = from p in Cert,
      where: (p.type == "root" or p.type == "tsp") and p.active,
      left_join: c in Cert,
      on: c.parent == p.id and c.type == "ocsp" and c.active,
      select: {p.type, p.data, c.data}


    query
    |> Repo.all()
    |> generate_map()
  end

  defp generate_map(certs) do
    map = %{
      general: [],
      tsp: []
    }
    Enum.reduce(certs, map, &process_cert(&1, &2))
  end

  defp process_cert({"root", rootCert, ocspCert}, map) do
    general =
      map
      |> Map.get(:general)
      |> Kernel.++([%{root: prepare_cert_data(rootCert), ocsp: prepare_cert_data(ocspCert)}])

    Map.put(map, :general, general)
  end
  defp process_cert({"tsp", tspCert, _}, map) do
    tsp =
      map
      |> Map.get(:tsp)
      |> Kernel.++([prepare_cert_data(tspCert)])

    Map.put(map, :tsp, tsp)
  end

  defp prepare_cert_data(nil), do: nil
  defp prepare_cert_data(data), do: :erlang.binary_to_list(data)
end
