defmodule MyappWeb.SeriesController do
  use MyappWeb, :controller
  use PhoenixSwagger
  alias Mongo

  @collection "series"
  @races_collection "races"
  @classes_collection "boat_classes"

  # =========================
  # Swagger
  # =========================

  swagger_path :create_serie do
    post("/series")
    summary("Créer une série")
    description("Crée une nouvelle série")
    consumes("application/json")

    parameter(:body, :body, Schema.ref(:SerieInput), "Informations de la série", required: true)

    response(200, "Série créée", Schema.ref(:Serie))
    response(400, "Paramètre manquant", Schema.ref(:Error))
    response(500, "Erreur serveur", Schema.ref(:Error))

    security([%{"Bearer" => []}])
  end

  swagger_path :get_series do
    get("/getSeries")
    summary("Lister les séries")
    description("Retourne la liste des séries")

    response(200, "Liste des séries", Schema.array(:Serie))
    response(500, "Erreur serveur", Schema.ref(:Error))

    security([%{"Bearer" => []}])
  end

  swagger_path :update_serie do
    put("/series/{id}")
    summary("Modifier une série")
    description("Met à jour une série existante")
    consumes("application/json")

    parameter(:id, :path, :string, "ID de la série", required: true)

    parameter(
      :body,
      :body,
      Schema.ref(:SerieUpdateInput),
      "Nouvelles informations de la série",
      required: true
    )

    response(200, "Série mise à jour")
    response(400, "ID invalide", Schema.ref(:Error))
    response(404, "Série introuvable", Schema.ref(:Error))
    response(500, "Erreur serveur", Schema.ref(:Error))

    security([%{"Bearer" => []}])
  end

  swagger_path :delete_serie do
    delete("/series/{id}")
    summary("Supprimer une série")
    description("Supprime une série existante")

    parameter(:id, :path, :string, "ID de la série", required: true)

    response(200, "Série supprimée")
    response(400, "ID invalide", Schema.ref(:Error))
    response(404, "Série introuvable", Schema.ref(:Error))
    response(500, "Erreur serveur", Schema.ref(:Error))

    security([%{"Bearer" => []}])
  end

  swagger_path :add_race_to_serie do
    put("/series/{id}/addRace")
    summary("Ajouter une course à une série")
    description("Ajoute une course compatible à la série")
    consumes("application/json")

    parameter(:id, :path, :string, "ID de la série", required: true)
    parameter(:body, :body, Schema.ref(:SerieRaceInput), "Course à ajouter", required: true)

    response(200, "Course ajoutée à la série")
    response(400, "ID invalide ou course incompatible", Schema.ref(:Error))
    response(404, "Série ou course introuvable", Schema.ref(:Error))
    response(500, "Erreur serveur", Schema.ref(:Error))

    security([%{"Bearer" => []}])
  end

  swagger_path :remove_race_from_serie do
    put("/series/{id}/removeRace")
    summary("Retirer une course d'une série")
    description("Retire l'ID d'une course de race_ids")
    consumes("application/json")

    parameter(:id, :path, :string, "ID de la série", required: true)
    parameter(:body, :body, Schema.ref(:SerieRaceInput), "Course à retirer", required: true)

    response(200, "Course retirée de la série")
    response(400, "ID invalide", Schema.ref(:Error))
    response(404, "Série introuvable", Schema.ref(:Error))
    response(500, "Erreur serveur", Schema.ref(:Error))

    security([%{"Bearer" => []}])
  end

  swagger_path :add_participant_to_serie do
    post("/addparticipanttoserie")
    summary("Inscrire un participant à une série")
    description("Ajoute un bateau à une série et l'inscrit à toutes les courses de cette série")
    consumes("application/json")

    parameter(
      :body,
      :body,
      Schema.ref(:SerieParticipantInput),
      "Participant à ajouter",
      required: true
    )

    response(200, "Participant ajouté à la série")
    response(400, "Données invalides", Schema.ref(:Error))
    response(404, "Série ou bateau introuvable", Schema.ref(:Error))
    response(409, "Participant déjà inscrit", Schema.ref(:Error))
    response(500, "Erreur serveur", Schema.ref(:Error))

    security([%{"Bearer" => []}])
  end

  swagger_path :remove_participant_from_serie do
    delete("/removeparticipantfromserie/{serie_id}/{boat_id}")
    summary("Retirer un participant d'une série")
    description("Retire un bateau d'une série et de toutes les courses liées")

    parameter(:serie_id, :path, :string, "ID de la série", required: true)
    parameter(:boat_id, :path, :string, "ID du bateau", required: true)

    response(200, "Participant retiré de la série")
    response(400, "Données invalides", Schema.ref(:Error))
    response(404, "Série ou participant introuvable", Schema.ref(:Error))
    response(500, "Erreur serveur", Schema.ref(:Error))

    security([%{"Bearer" => []}])
  end

  def swagger_definitions do
    %{
      Serie:
        swagger_schema do
          title("Serie")
          description("Représentation d'une série")

          properties do
            id(:string, "ID de la série")
            nom(:string, "Nom de la série")
            type(:string, "Type de série")
            classe(:string, "Classe")
            class_id(:string, "ID de la classe")
            boat_class_id(:string, "ID de la classe de bateau")
            type_handicap(:string, "Type de handicap")
            handicap_value(:number, "Valeur de handicap")
            nombreCourses(:integer, "Nombre de courses")
            nombreComptabilisees(:integer, "Nombre de courses comptabilisées")
            description(:string, "Description")
            race_ids(Schema.array(:string), "IDs des courses liées")
            participants(Schema.array(:SerieParticipant), "Participants inscrits à la série")
          end
        end,
      SerieInput:
        swagger_schema do
          title("SerieInput")
          description("Données pour créer une série")

          properties do
            nom(:string, "Nom de la série", required: true)
            type(:string, "Type OD ou H")
            class_id(:string, "ID de la classe de bateau")
            boat_class_id(:string, "ID de la classe de bateau")
            nombreCourses(:integer, "Nombre de courses")
            nombreComptabilisees(:integer, "Nombre comptabilisé")
            description(:string, "Description")
            race_ids(Schema.array(:string), "IDs des courses liées")
          end
        end,
      SerieUpdateInput:
        swagger_schema do
          title("SerieUpdateInput")
          description("Données pour modifier une série")

          properties do
            nom(:string, "Nom de la série")
            type(:string, "Type OD ou H")
            class_id(:string, "ID de la classe de bateau")
            boat_class_id(:string, "ID de la classe de bateau")
            nombreCourses(:integer, "Nombre de courses")
            nombreComptabilisees(:integer, "Nombre comptabilisé")
            description(:string, "Description")
            race_ids(Schema.array(:string), "IDs des courses liées")
          end
        end,
      SerieRaceInput:
        swagger_schema do
          title("SerieRaceInput")
          description("Payload pour ajouter ou retirer une course d'une série")

          properties do
            race_id(:string, "ID de la course", required: true)
          end
        end,
      SerieParticipant:
        swagger_schema do
          title("SerieParticipant")
          description("Participant inscrit à une série")

          properties do
            boat_id(:string, "ID du bateau")
            boat_name(:string, "Nom du bateau")
            sail_number(:string, "Numéro de voile")
            boat_class(:string, "Classe du bateau")
            class_id(:string, "ID de la classe")
            boat_class_id(:string, "ID de la classe de bateau")
            type_handicap(:string, "Type de handicap")
            handicap_value(:number, "Valeur de handicap")
            helm_name(:string, "Nom du barreur")
            inserted_at(:string, "Date d'ajout")
          end
        end,
      SerieParticipantInput:
        swagger_schema do
          title("SerieParticipantInput")
          description("Données pour inscrire un bateau à une série")

          properties do
            serie_id(:string, "ID de la série", required: true)
            boat_id(:string, "ID du bateau", required: true)
          end
        end,
      Error:
        swagger_schema do
          title("Error")
          description("Réponse d'erreur")

          properties do
            error(:string, "Message d'erreur")
          end
        end
    }
  end

  # =========================
  # CRUD séries
  # =========================

  # POST /api/series
  def create_serie(conn, params) do
    with {:ok, nom} <- Map.fetch(params, "nom") do
      type = normalize_type(Map.get(params, "type", "OD"))
      class_id = normalize_class_id_for_type(type, params)

      race_ids =
        case Map.get(params, "race_ids", []) do
          ids when is_list(ids) -> ids
          _ -> []
        end

      with :ok <- validate_type(type),
     {:ok, boat_class} <- get_required_class_for_type(type, class_id),
     :ok <- validate_races_for_serie_type_and_class(type, class_id, race_ids) do
        serie = %{
          "nom" => nom,
          "type" => type,
          "class_id" => class_id,
          "boat_class_id" => class_id,
          "classe" => class_display_name(boat_class),
          "type_handicap" => class_handicap_type(boat_class),
          "handicap_value" => class_handicap_value(boat_class),
          "nombreCourses" => Map.get(params, "nombreCourses", 2),
          "nombreComptabilisees" => Map.get(params, "nombreComptabilisees", 1),
          "description" => Map.get(params, "description", ""),
          "race_ids" => race_ids,
          "participants" => []
        }

        case Mongo.insert_one(:mongo, @collection, serie) do
          {:ok, result} ->
            json(conn, serialize_serie(Map.put(serie, "_id", result.inserted_id)))

          {:error, reason} ->
            conn
            |> put_status(500)
            |> json(%{error: inspect(reason)})
        end
      else
        {:error, status, message} ->
          conn
          |> put_status(status)
          |> json(%{error: message})
      end
    else
      :error ->
        conn
        |> put_status(400)
        |> json(%{error: "Missing parameter: nom"})
    end
  end

  # GET /api/getSeries
  def get_series(conn, _params) do
    series =
      Mongo.find(:mongo, @collection, %{})
      |> Enum.map(&serialize_serie/1)

    json(conn, series)
  end

  # PUT /api/series/:id
  def update_serie(conn, %{"id" => id} = params) do
    with {:ok, object_id} <- decode_object_id(id),
         {:ok, existing_serie} <- get_serie_by_id(object_id) do
      type = normalize_type(Map.get(params, "type", existing_serie["type"] || "OD"))
      class_id = normalize_class_id_for_type(type, params, existing_serie)

      race_ids =
        case Map.get(params, "race_ids", existing_serie["race_ids"] || []) do
          ids when is_list(ids) -> ids
          _ -> []
        end

      with :ok <- validate_type(type),
        :ok <- ensure_type_and_class_can_be_modified(existing_serie, type, class_id),
        {:ok, boat_class} <- get_required_class_for_type(type, class_id),
        :ok <- validate_races_for_serie_type_and_class(type, class_id, race_ids) do
        updates = %{
          "nom" => Map.get(params, "nom", existing_serie["nom"] || ""),
          "type" => type,
          "class_id" => class_id,
          "boat_class_id" => class_id,
          "classe" => class_display_name(boat_class),
          "type_handicap" => class_handicap_type(boat_class),
          "handicap_value" => class_handicap_value(boat_class),
          "nombreCourses" =>
            Map.get(params, "nombreCourses", existing_serie["nombreCourses"] || 2),
          "nombreComptabilisees" =>
            Map.get(params, "nombreComptabilisees", existing_serie["nombreComptabilisees"] || 1),
          "description" => Map.get(params, "description", existing_serie["description"] || ""),
          "race_ids" => race_ids
        }

        case Mongo.update_one(
               :mongo,
               @collection,
               %{"_id" => object_id},
               %{"$set" => updates}
             ) do
          {:ok, _} ->
            json(conn, %{message: "Serie updated"})

          {:error, reason} ->
            conn
            |> put_status(500)
            |> json(%{error: inspect(reason)})
        end
      else
        {:error, status, message} ->
          conn
          |> put_status(status)
          |> json(%{error: message})
      end
    else
      {:error, :invalid_object_id} ->
        conn
        |> put_status(400)
        |> json(%{error: "Invalid id"})

      {:error, :serie_not_found} ->
        conn
        |> put_status(404)
        |> json(%{error: "Serie not found"})
    end
  end

  # DELETE /api/series/:id
  def delete_serie(conn, %{"id" => id}) do
    with {:ok, object_id} <- decode_object_id(id),
         {:ok, serie} <- get_serie_by_id(object_id) do
      delete_linked_races(serie)

      case Mongo.delete_one(:mongo, @collection, %{"_id" => object_id}) do
        {:ok, _} ->
          json(conn, %{
            message: "Serie deleted",
            deleted_race_ids: Map.get(serie, "race_ids", [])
          })

        {:error, reason} ->
          conn
          |> put_status(500)
          |> json(%{error: inspect(reason)})
      end
    else
      {:error, :invalid_object_id} ->
        conn
        |> put_status(400)
        |> json(%{error: "Invalid id"})

      {:error, :serie_not_found} ->
        conn
        |> put_status(404)
        |> json(%{error: "Serie not found"})
    end
  end

  # =========================
  # Courses liées à la série
  # =========================

  # PUT /api/series/:id/addRace
  def add_race_to_serie(conn, %{"id" => id, "race_id" => race_id}) do
    with {:ok, object_id} <- decode_object_id(id),
         {:ok, serie} <- get_serie_by_id(object_id),
         {:ok, race_object_id} <- decode_object_id(race_id),
         {:ok, race} <- get_race_by_id(race_object_id),
         :ok <- ensure_race_compatible_with_serie(serie, race) do
      case Mongo.update_one(
             :mongo,
             @collection,
             %{"_id" => object_id},
             %{"$addToSet" => %{"race_ids" => race_id}}
           ) do
        {:ok, _} ->
          sync_existing_series_participants_to_race(serie, race_id)
          json(conn, %{message: "Race added to serie"})

        {:error, reason} ->
          conn
          |> put_status(500)
          |> json(%{error: inspect(reason)})
      end
    else
      {:error, :invalid_object_id} ->
        conn
        |> put_status(400)
        |> json(%{error: "Invalid id or race_id"})

      {:error, :serie_not_found} ->
        conn
        |> put_status(404)
        |> json(%{error: "Serie not found"})

      {:error, :race_not_found} ->
        conn
        |> put_status(404)
        |> json(%{error: "Race not found"})

      {:error, :race_not_compatible} ->
        conn
        |> put_status(400)
        |> json(%{error: "La course n'est pas compatible avec le type ou la classe de la série"})
    end
  end

  # PUT /api/series/:id/removeRace
  def remove_race_from_serie(conn, %{"id" => id, "race_id" => race_id}) do
    with {:ok, object_id} <- decode_object_id(id),
         {:ok, _serie} <- get_serie_by_id(object_id) do
      case Mongo.update_one(
             :mongo,
             @collection,
             %{"_id" => object_id},
             %{"$pull" => %{"race_ids" => race_id}}
           ) do
        {:ok, _} ->
          json(conn, %{message: "Race removed from serie"})

        {:error, reason} ->
          conn
          |> put_status(500)
          |> json(%{error: inspect(reason)})
      end
    else
      {:error, :invalid_object_id} ->
        conn
        |> put_status(400)
        |> json(%{error: "Invalid id"})

      {:error, :serie_not_found} ->
        conn
        |> put_status(404)
        |> json(%{error: "Serie not found"})
    end
  end

  # =========================
  # Participants de série
  # =========================

  # POST /api/addparticipanttoserie
  def add_participant_to_serie(conn, params) do
    with {:ok, serie_id} <- Map.fetch(params, "serie_id"),
         {:ok, boat_id} <- Map.fetch(params, "boat_id"),
         {:ok, serie_object_id} <- decode_object_id(serie_id),
         {:ok, boat_object_id} <- decode_object_id(boat_id),
         {:ok, serie} <- get_serie_by_id(serie_object_id),
         {:ok, boat} <- MyappWeb.BoatController.get_boat_by_id(boat_object_id),
         :ok <- ensure_boat_matches_serie_class(serie, boat),
         :ok <- ensure_serie_participant_not_already_registered(serie, boat_id, boat["noVoile"]) do
      participant = %{
        "boat_id" => boat_id,
        "boat_name" => boat["nom"],
        "sail_number" => boat["noVoile"],
        "boat_class" => boat["classe"],
        "class_id" => boat["class_id"] || boat["boat_class_id"],
        "boat_class_id" => boat["boat_class_id"] || boat["class_id"],
        "type_handicap" => boat["type_handicap"],
        "handicap_value" => boat["valeur_handicap"],
        "helm_name" => boat["NomBarreur"],
        "inserted_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      }

      case Mongo.update_one(
             :mongo,
             @collection,
             %{"_id" => serie_object_id},
             %{"$push" => %{"participants" => participant}}
           ) do
        {:ok, _} ->
          sync_participant_to_series_races(serie, participant)

          json(conn, %{
            message: "Participant ajouté à la série et à ses courses",
            serie_id: serie_id,
            participant: participant
          })

        {:error, reason} ->
          conn
          |> put_status(500)
          |> json(%{error: inspect(reason)})
      end
    else
      :error ->
        conn
        |> put_status(400)
        |> json(%{error: "Missing parameters (serie_id, boat_id)"})

      {:error, :invalid_object_id} ->
        conn
        |> put_status(400)
        |> json(%{error: "Invalid serie_id or boat_id"})

      {:error, :serie_not_found} ->
        conn
        |> put_status(404)
        |> json(%{error: "Serie not found"})

      {:error, :boat_not_found} ->
        conn
        |> put_status(404)
        |> json(%{error: "Boat not found"})

      {:error, :boat_class_not_allowed} ->
        conn
        |> put_status(400)
        |> json(%{error: "Ce bateau ne respecte pas la classe requise pour cette série"})

      {:error, :participant_already_registered} ->
        conn
        |> put_status(409)
        |> json(%{error: "Participant already registered for this serie"})
    end
  end

  # DELETE /api/removeparticipantfromserie/:serie_id/:boat_id
  def remove_participant_from_serie(conn, %{"serie_id" => serie_id, "boat_id" => boat_id}) do
    with {:ok, object_id} <- decode_object_id(serie_id),
         {:ok, serie} <- get_serie_by_id(object_id),
         :ok <- ensure_serie_participant_exists(serie, boat_id) do
      case Mongo.update_one(
             :mongo,
             @collection,
             %{"_id" => object_id},
             %{"$pull" => %{"participants" => %{"boat_id" => boat_id}}}
           ) do
        {:ok, _} ->
          remove_participant_from_series_races(serie, boat_id)

          json(conn, %{
            message: "Participant retiré de la série et de ses courses",
            serie_id: serie_id,
            boat_id: boat_id
          })

        {:error, reason} ->
          conn
          |> put_status(500)
          |> json(%{error: inspect(reason)})
      end
    else
      {:error, :invalid_object_id} ->
        conn
        |> put_status(400)
        |> json(%{error: "Invalid serie_id"})

      {:error, :serie_not_found} ->
        conn
        |> put_status(404)
        |> json(%{error: "Serie not found"})

      {:error, :participant_not_found} ->
        conn
        |> put_status(404)
        |> json(%{error: "Participant not found in this serie"})
    end
  end

  # =========================
  # Helpers
  # =========================

  defp get_serie_by_id(object_id) do
    case Mongo.find_one(:mongo, @collection, %{"_id" => object_id}) do
      nil -> {:error, :serie_not_found}
      serie -> {:ok, serie}
    end
  end

  defp get_race_by_id(object_id) do
    case Mongo.find_one(:mongo, @races_collection, %{"_id" => object_id}) do
      nil -> {:error, :race_not_found}
      race -> {:ok, race}
    end
  end

  defp get_class_by_id(object_id) do
    case Mongo.find_one(:mongo, @classes_collection, %{"_id" => object_id}) do
      nil -> {:error, :class_not_found}
      boat_class -> {:ok, boat_class}
    end
  end

  defp validate_type(type) when type in ["OD", "H"], do: :ok
  defp validate_type(_), do: {:error, 400, "Le type doit être OD ou H"}

  defp normalize_type(type) do
    type
    |> to_string()
    |> String.trim()
    |> String.upcase()
  end

  defp normalize_class_id_for_type("H", _params), do: ""

  defp normalize_class_id_for_type("OD", params) do
    Map.get(params, "class_id") || Map.get(params, "boat_class_id") || ""
  end

  defp normalize_class_id_for_type("H", _params, _existing_serie), do: ""

  defp normalize_class_id_for_type("OD", params, existing_serie) do
    Map.get(params, "class_id") ||
      Map.get(params, "boat_class_id") ||
      existing_serie["class_id"] ||
      existing_serie["boat_class_id"] ||
      ""
  end

  defp get_required_class_for_type("H", _class_id), do: {:ok, nil}

  defp get_required_class_for_type("OD", class_id) when class_id in [nil, ""] do
    {:error, 400, "La classe est obligatoire pour une série OD"}
  end

  defp get_required_class_for_type("OD", class_id) do
    with {:ok, class_object_id} <- decode_object_id(class_id),
         {:ok, boat_class} <- get_class_by_id(class_object_id) do
      {:ok, boat_class}
    else
      {:error, :invalid_object_id} ->
        {:error, 400, "Identifiant de classe invalide"}

      {:error, :class_not_found} ->
        {:error, 404, "Classe de bateau introuvable"}
    end
  end

  defp class_display_name(nil), do: ""
  defp class_display_name(boat_class), do: boat_class["display_name"] || boat_class["name"] || ""

  defp class_handicap_type(nil), do: nil
  defp class_handicap_type(boat_class), do: boat_class["handicap_type"]

  defp class_handicap_value(nil), do: nil
  defp class_handicap_value(boat_class), do: boat_class["handicap_value"]

  defp validate_races_for_serie_type_and_class(type, class_id, race_ids) do
    race_ids
    |> Enum.reduce_while(:ok, fn race_id, :ok ->
      with {:ok, race_object_id} <- decode_object_id(race_id),
           {:ok, race} <- get_race_by_id(race_object_id),
           :ok <- ensure_race_matches_type_and_class(type, class_id, race) do
        {:cont, :ok}
      else
        {:error, :invalid_object_id} ->
          {:halt, {:error, 400, "Un des IDs de course est invalide"}}

        {:error, :race_not_found} ->
          {:halt, {:error, 404, "Une des courses est introuvable"}}

        {:error, :race_not_compatible} ->
          {:halt,
           {:error, 400,
            "Une des courses n'est pas compatible avec le type ou la classe de la série"}}
      end
    end)
  end

  defp ensure_race_matches_type_and_class("H", _class_id, race) do
    race_type = normalize_type(race["type"] || "OD")

    if race_type == "H" do
      :ok
    else
      {:error, :race_not_compatible}
    end
  end

  defp ensure_race_matches_type_and_class("OD", class_id, race) do
    race_type = normalize_type(race["type"] || "OD")
    race_class_id = race["class_id"] || race["boat_class_id"] || ""

    if race_type == "OD" and race_class_id == class_id do
      :ok
    else
      {:error, :race_not_compatible}
    end
  end

  defp ensure_race_compatible_with_serie(serie, race) do
    type = normalize_type(serie["type"] || "OD")
    class_id = serie["class_id"] || serie["boat_class_id"] || ""

    ensure_race_matches_type_and_class(type, class_id, race)
  end

  defp ensure_boat_matches_serie_class(serie, boat) do
    serie_type = normalize_type(serie["type"] || "OD")

    if serie_type == "H" do
      :ok
    else
      serie_class_id = serie["class_id"] || serie["boat_class_id"] || ""
      boat_class_id = boat["class_id"] || boat["boat_class_id"] || ""

      if serie_class_id != "" and boat_class_id == serie_class_id do
        :ok
      else
        {:error, :boat_class_not_allowed}
      end
    end
  end

  defp ensure_serie_participant_not_already_registered(serie, boat_id, sail_number) do
    participants = Map.get(serie, "participants", [])

    already_exists =
      Enum.any?(participants, fn participant ->
        (participant["boat_id"] || participant[:boat_id]) == boat_id or
          (participant["sail_number"] || participant[:sail_number]) == sail_number
      end)

    if already_exists do
      {:error, :participant_already_registered}
    else
      :ok
    end
  end

  defp ensure_serie_participant_exists(serie, boat_id) do
    participants = Map.get(serie, "participants", [])

    exists? =
      Enum.any?(participants, fn participant ->
        (participant["boat_id"] || participant[:boat_id]) == boat_id
      end)

    if exists? do
      :ok
    else
      {:error, :participant_not_found}
    end
  end

  defp sync_participant_to_series_races(serie, participant) do
    race_ids = Map.get(serie, "race_ids", [])

    Enum.each(race_ids, fn race_id ->
      with {:ok, race_object_id} <- decode_object_id(race_id),
           {:ok, race} <- get_race_by_id(race_object_id),
           :ok <- ensure_race_compatible_with_serie(serie, race) do
        existing_race_participants = Map.get(race, "participants", [])

        already_exists =
          Enum.any?(existing_race_participants, fn p ->
            (p["boat_id"] || p[:boat_id]) == participant["boat_id"]
          end)

        unless already_exists do
          race_participant = build_race_participant_from_serie_participant(participant)

          Mongo.update_one(
            :mongo,
            @races_collection,
            %{"_id" => race_object_id},
            %{"$push" => %{"participants" => race_participant}}
          )
        end
      else
        _ -> :ok
      end
    end)
  end

  defp remove_participant_from_series_races(serie, boat_id) do
    race_ids = Map.get(serie, "race_ids", [])

    Enum.each(race_ids, fn race_id ->
      with {:ok, race_object_id} <- decode_object_id(race_id) do
        Mongo.update_one(
          :mongo,
          @races_collection,
          %{"_id" => race_object_id},
          %{"$pull" => %{"participants" => %{"boat_id" => boat_id}}}
        )
      else
        _ -> :ok
      end
    end)
  end

  defp sync_existing_series_participants_to_race(serie, race_id) do
    participants = Map.get(serie, "participants", [])

    with {:ok, race_object_id} <- decode_object_id(race_id),
         {:ok, race} <- get_race_by_id(race_object_id),
         :ok <- ensure_race_compatible_with_serie(serie, race) do
      existing_race_participants = Map.get(race, "participants", [])

      Enum.each(participants, fn participant ->
        already_exists =
          Enum.any?(existing_race_participants, fn p ->
            (p["boat_id"] || p[:boat_id]) == (participant["boat_id"] || participant[:boat_id])
          end)

        unless already_exists do
          race_participant = build_race_participant_from_serie_participant(participant)

          Mongo.update_one(
            :mongo,
            @races_collection,
            %{"_id" => race_object_id},
            %{"$push" => %{"participants" => race_participant}}
          )
        end
      end)
    else
      _ -> :ok
    end
  end

  defp ensure_type_and_class_can_be_modified(existing_serie, new_type, new_class_id) do
  old_type = normalize_type(existing_serie["type"] || "OD")
  old_class_id = existing_serie["class_id"] || existing_serie["boat_class_id"] || ""

  existing_race_ids =
    case Map.get(existing_serie, "race_ids", []) do
      ids when is_list(ids) -> ids
      _ -> []
    end

  type_changed? = old_type != new_type
  class_changed? = old_class_id != new_class_id
  has_races? = length(existing_race_ids) > 0

  if has_races? and (type_changed? or class_changed?) do
    {:error, 400, "Impossible de modifier le type ou la classe d'une série qui contient déjà des courses"}
  else
    :ok
  end
end

  defp build_race_participant_from_serie_participant(participant) do
    %{
      "id" => System.unique_integer([:positive, :monotonic]),
      "boat_id" => participant["boat_id"] || participant[:boat_id],
      "boat_name" => participant["boat_name"] || participant[:boat_name],
      "sail_number" => participant["sail_number"] || participant[:sail_number],
      "boat_class" => participant["boat_class"] || participant[:boat_class],
      "class_id" =>
        participant["class_id"] || participant[:class_id] || participant["boat_class_id"] ||
          participant[:boat_class_id],
      "boat_class_id" =>
        participant["boat_class_id"] || participant[:boat_class_id] || participant["class_id"] ||
          participant[:class_id],
      "type_handicap" => participant["type_handicap"] || participant[:type_handicap],
      "handicap_value" => participant["handicap_value"] || participant[:handicap_value],
      "helm_name" => participant["helm_name"] || participant[:helm_name],
      "result" => nil,
      "position" => nil,
      "points" => nil,
      "inserted_at" => participant["inserted_at"] || participant[:inserted_at]
    }
  end

  defp delete_linked_races(serie) do
    race_ids = Map.get(serie, "race_ids", [])

    Enum.each(race_ids, fn race_id ->
      with {:ok, race_object_id} <- decode_object_id(race_id) do
        Mongo.delete_one(
          :mongo,
          @races_collection,
          %{"_id" => race_object_id}
        )
      else
        _ -> :ok
      end
    end)
  end

  defp serialize_serie(serie) do
    %{
      id: BSON.ObjectId.encode!(serie["_id"]),
      nom: serie["nom"] || "",
      type: serie["type"] || "OD",
      classe: serie["classe"] || "",
      class_id: serie["class_id"] || serie["boat_class_id"],
      boat_class_id: serie["boat_class_id"] || serie["class_id"],
      type_handicap: serie["type_handicap"],
      handicap_value: serie["handicap_value"],
      nombreCourses: serie["nombreCourses"] || 0,
      nombreComptabilisees: serie["nombreComptabilisees"] || 0,
      description: serie["description"] || "",
      race_ids: Map.get(serie, "race_ids", []),
      participants: Map.get(serie, "participants", [])
    }
  end

  defp decode_object_id(id) when is_binary(id) do
    try do
      {:ok, BSON.ObjectId.decode!(id)}
    rescue
      _ -> {:error, :invalid_object_id}
    end
  end

  defp decode_object_id(_), do: {:error, :invalid_object_id}
end
