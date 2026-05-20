defmodule MyappWeb.ClassesController do
  use MyappWeb, :controller
  use PhoenixSwagger

  alias Mongo

  @collection "boat_classes"
  @boats_collection "boats"

  # GET /api/classes
  def get_classes(conn, _params) do
    classes =
      Mongo.find(:mongo, @collection, %{})
      |> Enum.map(&normalize_class/1)

    json(conn, classes)
  end

  # POST /api/classes
  def add_class(conn, params) do
    with {:ok, name} <- fetch_required_string(params, "name"),
         {:ok, handicap_type} <- fetch_required_string(params, "handicap_type"),
         {:ok, handicap_value} <- fetch_required_number(params, "handicap_value"),
         :ok <- validate_class_name(name),
         {:ok, normalized_type} <- validate_handicap_type(handicap_type),
         :ok <- validate_handicap_value(normalized_type, handicap_value),
         :ok <- ensure_class_name_unique(name) do
      now = DateTime.utc_now() |> DateTime.to_iso8601()

      boat_class = %{
        "name" => normalize_class_name(name),
        "display_name" => String.trim(name),
        "handicap_type" => normalized_type,
        "handicap_value" => handicap_value,
        "inserted_at" => now,
        "updated_at" => now
      }

      case Mongo.insert_one(:mongo, @collection, boat_class) do
        {:ok, result} ->
          conn
          |> put_status(201)
          |> json(%{
            message: "Classe de bateau créée avec succès",
            class: Map.put(boat_class, "id", object_id_to_string(result.inserted_id))
          })

        {:error, reason} ->
          conn
          |> put_status(500)
          |> json(%{
            error: "Erreur serveur lors de la création de la classe",
            details: inspect(reason)
          })
      end
    else
      {:error, message} ->
        conn
        |> put_status(400)
        |> json(%{error: message})
    end
  end

  # PUT /api/classes/:class_id
  def update_class(conn, %{"class_id" => class_id} = params) do
    with {:ok, object_id} <- decode_object_id(class_id),
         {:ok, existing_class} <- get_class_by_id(object_id),
         {:ok, name} <- fetch_required_string(params, "name"),
         {:ok, handicap_type} <- fetch_required_string(params, "handicap_type"),
         {:ok, handicap_value} <- fetch_required_number(params, "handicap_value"),
         :ok <- validate_class_name(name),
         {:ok, normalized_type} <- validate_handicap_type(handicap_type),
         :ok <- validate_handicap_value(normalized_type, handicap_value),
         :ok <- ensure_class_name_unique_for_update(name, class_id) do
      updated_class = %{
        "name" => normalize_class_name(name),
        "display_name" => String.trim(name),
        "handicap_type" => normalized_type,
        "handicap_value" => handicap_value,
        "updated_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      }

      case Mongo.update_one(
             :mongo,
             @collection,
             %{"_id" => object_id},
             %{"$set" => updated_class}
           ) do
        {:ok, _result} ->
          conn
          |> json(%{
            message: "Classe de bateau modifiée avec succès",
            class: normalize_class(Map.merge(existing_class, updated_class))
          })

        {:error, reason} ->
          conn
          |> put_status(500)
          |> json(%{
            error: "Erreur serveur lors de la modification de la classe",
            details: inspect(reason)
          })
      end
    else
      {:error, :invalid_id} ->
        conn
        |> put_status(400)
        |> json(%{error: "Identifiant de classe invalide"})

      {:error, :not_found} ->
        conn
        |> put_status(404)
        |> json(%{error: "Classe de bateau introuvable"})

      {:error, message} ->
        conn
        |> put_status(400)
        |> json(%{error: message})
    end
  end

  # DELETE /api/classes/:class_id
  def delete_class(conn, %{"class_id" => class_id}) do
    with {:ok, object_id} <- decode_object_id(class_id),
         {:ok, boat_class} <- get_class_by_id(object_id),
         :ok <- ensure_class_not_used(boat_class) do
      case Mongo.delete_one(:mongo, @collection, %{"_id" => object_id}) do
        {:ok, _result} ->
          json(conn, %{message: "Classe de bateau supprimée avec succès"})

        {:error, reason} ->
          conn
          |> put_status(500)
          |> json(%{
            error: "Erreur serveur lors de la suppression de la classe",
            details: inspect(reason)
          })
      end
    else
      {:error, :invalid_id} ->
        conn
        |> put_status(400)
        |> json(%{error: "Identifiant de classe invalide"})

      {:error, :not_found} ->
        conn
        |> put_status(404)
        |> json(%{error: "Classe de bateau introuvable"})

      {:error, :class_used} ->
        conn
        |> put_status(409)
        |> json(%{
          error:
            "Impossible de supprimer cette classe, car elle est déjà utilisée par un ou plusieurs bateaux"
        })

      {:error, message} ->
        conn
        |> put_status(400)
        |> json(%{error: message})
    end
  end

  defp fetch_required_string(params, key) do
    case Map.get(params, key) do
      value when is_binary(value) ->
        trimmed = String.trim(value)

        if trimmed == "" do
          {:error, field_required_message(key)}
        else
          {:ok, trimmed}
        end

      _ ->
        {:error, field_required_message(key)}
    end
  end

  defp fetch_required_number(params, key) do
    case Map.get(params, key) do
      value when is_integer(value) or is_float(value) ->
        {:ok, value}

      value when is_binary(value) ->
        trimmed = String.trim(value)

        cond do
          trimmed == "" ->
            {:error, field_required_message(key)}

          Regex.match?(~r/^\d+(\.\d+)?$/, trimmed) ->
            {:ok, String.to_float(normalize_decimal(trimmed))}

          true ->
            {:error, "La valeur de handicap doit être un nombre valide"}
        end

      _ ->
        {:error, field_required_message(key)}
    end
  end

  defp normalize_decimal(value) do
    String.replace(value, ",", ".")
  end

  defp field_required_message("name"), do: "Le nom de la classe est obligatoire"
  defp field_required_message("handicap_type"), do: "Le type de handicap est obligatoire"
  defp field_required_message("handicap_value"), do: "La valeur de handicap est obligatoire"
  defp field_required_message(field), do: "Le champ #{field} est obligatoire"

  defp validate_class_name(name) do
    trimmed = String.trim(name)

    cond do
      trimmed == "" ->
        {:error, "Le nom de la classe est obligatoire"}

      String.length(trimmed) > 25 ->
        {:error, "Le nom de la classe doit avoir un maximum de 25 caractères"}

      not Regex.match?(~r/^[A-Za-zÀ-ÿ0-9 _-]+$/, trimmed) ->
        {:error,
         "Le nom de la classe peut contenir seulement des lettres, chiffres, espaces, - ou _"}

      true ->
        :ok
    end
  end

  defp validate_handicap_type(handicap_type) do
    normalized_type =
      handicap_type
      |> String.trim()
      |> String.upcase()

    case normalized_type do
      "PY" -> {:ok, "PY"}
      "TMF" -> {:ok, "TMF"}
      _ -> {:error, "Le type de handicap doit être PY ou TMF"}
    end
  end

  defp validate_handicap_value("PY", value) do
    cond do
      not is_number(value) ->
        {:error, "La valeur PY doit être un nombre"}

      value <= 0 ->
        {:error, "La valeur PY doit être plus grande que 0"}

      value != trunc(value) ->
        {:error, "La valeur PY doit être un nombre entier"}

      String.length(Integer.to_string(trunc(value))) != 4 ->
        {:error, "La valeur PY doit être un entier à 4 chiffres"}

      true ->
        :ok
    end
  end

  defp validate_handicap_value("TMF", value) do
    cond do
      not is_number(value) ->
        {:error, "La valeur TMF doit être un nombre"}

      value <= 0 ->
        {:error, "La valeur TMF doit être plus grande que 0"}

      true ->
        :ok
    end
  end

  defp ensure_class_name_unique(name) do
    normalized_name = normalize_class_name(name)

    existing_class =
      Mongo.find_one(:mongo, @collection, %{"name" => normalized_name})

    if existing_class do
      {:error, "Une classe avec ce nom existe déjà"}
    else
      :ok
    end
  end

  defp ensure_class_name_unique_for_update(name, current_class_id) do
    normalized_name = normalize_class_name(name)

    existing_class =
      Mongo.find_one(:mongo, @collection, %{"name" => normalized_name})

    cond do
      is_nil(existing_class) ->
        :ok

      object_id_to_string(existing_class["_id"]) == current_class_id ->
        :ok

      true ->
        {:error, "Une classe avec ce nom existe déjà"}
    end
  end

  defp ensure_class_not_used(boat_class) do
    class_id = object_id_to_string(boat_class["_id"])
    class_name = boat_class["name"]
    display_name = boat_class["display_name"]

    used_boat =
      Mongo.find_one(:mongo, @boats_collection, %{
        "$or" => [
          %{"class_id" => class_id},
          %{"boat_class_id" => class_id},
          %{"classeBateau" => display_name},
          %{"classe" => display_name},
          %{"classe" => class_name},
          %{"class" => display_name},
          %{"class" => class_name}
        ]
      })

    if used_boat do
      {:error, :class_used}
    else
      :ok
    end
  end

  defp get_class_by_id(object_id) do
    case Mongo.find_one(:mongo, @collection, %{"_id" => object_id}) do
      nil -> {:error, :not_found}
      boat_class -> {:ok, boat_class}
    end
  end

  defp decode_object_id(id) when is_binary(id) do
    case BSON.ObjectId.decode(id) do
      {:ok, object_id} -> {:ok, object_id}
      _ -> {:error, :invalid_id}
    end
  end

  defp decode_object_id(_), do: {:error, :invalid_id}

  defp normalize_class_name(name) do
    name
    |> String.trim()
    |> String.downcase()
  end

  defp normalize_class(boat_class) do
    %{
      "id" => object_id_to_string(boat_class["_id"]),
      "name" => boat_class["display_name"] || boat_class["name"],
      "normalized_name" => boat_class["name"],
      "handicap_type" => boat_class["handicap_type"],
      "handicap_value" => boat_class["handicap_value"],
      "inserted_at" => boat_class["inserted_at"],
      "updated_at" => boat_class["updated_at"]
    }
  end

  defp object_id_to_string(%BSON.ObjectId{} = object_id) do
    BSON.ObjectId.encode!(object_id)
  end

  defp object_id_to_string(value), do: value
end
