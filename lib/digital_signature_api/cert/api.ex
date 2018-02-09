defmodule DigitalSignature.Cert.API do
  @moduledoc false

  import Ecto.{Query, Changeset}, warn: false
  alias DigitalSignature.Repo
  alias DigitalSignature.Cert

  def get_certs_map do
    query =
      from(
        p in Cert,
        where: p.type in ["root", "tsp"] and p.active,
        left_join: c in Cert,
        on: c.parent == p.id and c.type == "ocsp" and c.active,
        select: {p.type, p.data, c.data}
      )

    query
    |> Repo.all()
    |> Enum.reduce(%{general: [], tsp: []}, &process_cert(&1, &2))
  end

  defp process_cert({"root", root_cert, ocsp_ert}, %{general: general} = map) do
    new_root = %{root: root_cert, ocsp: ocsp_ert}

    Map.put(map, :general, [new_root | general])
  end

  defp process_cert({"tsp", tsp_cert, _}, %{tsp: tsp} = map) do
    Map.put(map, :tsp, [tsp_cert | tsp])
  end
end
