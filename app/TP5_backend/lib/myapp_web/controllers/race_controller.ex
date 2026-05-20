defmodule MyappWeb.RaceController do
  use MyappWeb, :controller
  use PhoenixSwagger
  alias Mongo

  @collection "races"
  @classes_collection "boat_classes"
  @series_collection "series"

  swagger_path :add_race do
    post("/addrace")
    summary("Ajouter une course")
    description("Crée une nouvelle course")
    consumes("application/json")

    parameter(:body, :body, Schema.ref(:RaceInput), "Informations de la course", required: true)

    response(200, "Course ajoutée", Schema.ref(:RaceCreateResponse))
    response(400, "Paramètres manquants", Schema.ref(:Error))
    response(500, "Erreur serveur", Schema.ref(:Error))

    security([%{"Bearer" => []}])
  end

  swagger_path :delete_race do
    delete("/deleterace/{race_id}")
    summary("Supprimer une course")
    description("Supprime une course existante")

    parameter(:race_id, :path, :string, "ID de la course", required: true)

    response(200, "Course supprimée")
    response(400, "ID invalide", Schema.ref(:Error))
    response(404, "Course introuvable", Schema.ref(:Error))
    response(500, "Erreur serveur", Schema.ref(:Error))

    security([%{"Bearer" => []}])
  end

  swagger_path :get_races do
    get("/getraces")
    summary("Lister les courses")
    description("Retourne la liste des courses")

    response(200, "Liste des courses", Schema.array(:Race))
    response(500, "Erreur serveur", Schema.ref(:Error))

    security([%{"Bearer" => []}])
  end

  swagger_path :update_race do
    put("/updaterace/{race_id}")
    summary("Modifier une course")
    description("Met à jour les informations d'une course")
    consumes("application/json")

    parameter(:race_id, :path, :string, "ID de la course", required: true)
    parameter(:body, :body, Schema.ref(:RaceInput), "Informations mises à jour", required: true)

    response(200, "Course modifiée")
    response(400, "ID invalide ou données invalides", Schema.ref(:Error))
    response(404, "Course introuvable", Schema.ref(:Error))
    response(500, "Erreur serveur", Schema.ref(:Error))

    security([%{"Bearer" => []}])
  end

  swagger_path :set_race_finished do
    put("/setracefinished/{race_id}")
    summary("Changer l'état d'une course")
    description("Marque une course comme terminée ou non terminée")
    consumes("application/json")

    parameter(:race_id, :path, :string, "ID de la course", required: true)
    parameter(:body, :body, Schema.ref(:RaceFinishedInput), "État terminé", required: true)

    response(200, "État mis à jour")
    response(400, "ID invalide", Schema.ref(:Error))
    response(404, "Course introuvable", Schema.ref(:Error))
    response(500, "Erreur serveur", Schema.ref(:Error))

    security([%{"Bearer" => []}])
  end

  swagger_path :update_race_results do
    put("/updateraceresults/{race_id}")
    summary("Mettre à jour les résultats d'une course")
    description("Remplace la liste des participants/résultats d'une course")
    consumes("application/json")

    parameter(:race_id, :path, :string, "ID de la course", required: true)

    parameter(:body, :body, Schema.ref(:RaceResultsInput), "Participants et résultats",
      required: true
    )

    response(200, "Résultats mis à jour")
    response(400, "ID invalide", Schema.ref(:Error))
    response(404, "Course introuvable", Schema.ref(:Error))
    response(500, "Erreur serveur", Schema.ref(:Error))

    security([%{"Bearer" => []}])
  end

  swagger_path :add_participant_to_race do
    post("/addparticipanttorace")
    summary("Ajouter un participant à une course")
    description("Ajoute un bateau à une course non terminée")
    consumes("application/json")

    parameter(:body, :body, Schema.ref(:ParticipantInput), "Participant à ajouter",
      required: true
    )

    response(200, "Participant ajouté", Schema.ref(:ParticipantAddResponse))
    response(400, "Données invalides", Schema.ref(:Error))
    response(404, "Course introuvable", Schema.ref(:Error))
    response(409, "Participant déjà inscrit", Schema.ref(:Error))
    response(500, "Erreur serveur", Schema.ref(:Error))

    security([%{"Bearer" => []}])
  end

  swagger_path :remove_participant_from_race do
    delete("/removeparticipantfromrace/{race_id}/{participant_id}")
    summary("Retirer un participant d'une course")
    description("Retire un participant d'une course non terminée")

    parameter(:race_id, :path, :string, "ID de la course", required: true)
    parameter(:participant_id, :path, :string, "ID du participant", required: true)

    response(200, "Participant retiré")
    response(400, "Paramètres invalides", Schema.ref(:Error))
    response(404, "Course ou participant introuvable", Schema.ref(:Error))
    response(500, "Erreur serveur", Schema.ref(:Error))

    security([%{"Bearer" => []}])
  end

  swagger_path :get_participants_for_race do
    get("/getparticipantsforrace/{race_id}")
    summary("Lister les participants d'une course")
    description("Retourne les participants d'une course")

    parameter(:race_id, :path, :string, "ID de la course", required: true)

    response(200, "Liste des participants", Schema.array(:Participant))
    response(400, "ID invalide", Schema.ref(:Error))
    response(404, "Course introuvable", Schema.ref(:Error))

    security([%{"Bearer" => []}])
  end

  def swagger_definitions do
    %{
      Race:
        swagger_schema do
          title("Race")
          description("Représentation d'une course")

          properties do
            id(:string, "ID de la course")
            name(:string, "Nom de la course")
            type(:string, "Type de course")
            class(:string, "Classe")
            class_id(:string, "ID de la classe")
            boat_class_id(:string, "ID de la classe de bateau")
            type_handicap(:string, "Type de handicap")
            handicap_value(:number, "Valeur de handicap")
            date(:string, "Date")
            start_time(:string, "Heure de départ")
            course(:string, "Parcours")
            description(:string, "Description")
            finished(:boolean, "Course terminée")
            participants(Schema.array(:Participant), "Participants")
          end
        end,
      RaceInput:
        swagger_schema do
          title("RaceInput")
          description("Données pour créer ou modifier une course")

          properties do
            name(:string, "Nom de la course", required: true)
            type(:string, "Type de course")
            class_id(:string, "ID de la classe de bateau")
            date(:string, "Date", required: true)
            start_time(:string, "Heure de départ")
            course(:string, "Parcours")
            description(:string, "Description")
          end

          example(%{
            name: "Course du samedi",
            type: "OD",
            class_id: "67f123456789abcdef123456",
            date: "2026-04-30",
            start_time: "13:00",
            course: "Triangle",
            description: "Course d'entraînement"
          })
        end,
      RaceCreateResponse:
        swagger_schema do
          title("RaceCreateResponse")
          description("Réponse après création d'une course")

          properties do
            message(:string, "Message")
            id(:string, "ID de la course")
          end
        end,
      RaceFinishedInput:
        swagger_schema do
          title("RaceFinishedInput")
          description("État terminé ou non")

          properties do
            finished(:boolean, "true si la course est terminée", required: true)
          end
        end,
      Participant:
        swagger_schema do
          title("Participant")
          description("Participant inscrit à une course")

          properties do
            id(:integer, "ID du participant")
            boat_id(:string, "ID du bateau")
            boat_name(:string, "Nom du bateau")
            sail_number(:string, "Numéro de voile")
            boat_class(:string, "Classe du bateau")
            class_id(:string, "ID de la classe")
            boat_class_id(:string, "ID de la classe de bateau")
            type_handicap(:string, "Type de handicap")
            handicap_value(:number, "Valeur de handicap")
            helm_name(:string, "Nom du barreur")
            result(:string, "Résultat")
            position(:integer, "Position")
            points(:integer, "Points")
            inserted_at(:string, "Date d'ajout")
          end
        end,
      ParticipantInput:
        swagger_schema do
          title("ParticipantInput")
          description("Données pour ajouter un participant à une course")

          properties do
            race_id(:string, "ID de la course", required: true)
            boat_id(:string, "ID du bateau", required: true)
          end
        end,
      ParticipantAddResponse:
        swagger_schema do
          title("ParticipantAddResponse")
          description("Réponse après ajout d'un participant")

          properties do
            message(:string, "Message")
            race_id(:string, "ID de la course")
            participant(Schema.ref(:Participant), "Participant ajouté")
          end
        end,
      RaceResultsInput:
        swagger_schema do
          title("RaceResultsInput")
          description("Résultats complets d'une course")

          properties do
            participants(Schema.array(:Participant), "Liste des participants", required: true)
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

  # POST /api/addrace
  def add_race(conn, params) do
    with {:ok, name} <- Map.fetch(params, "name"),
         {:ok, date} <- Map.fetch(params, "date") do
      class_id = Map.get(params, "class_id") || Map.get(params, "boat_class_id")

      case get_optional_class(class_id) do
        {:ok, boat_class} ->
          race = %{
            "name" => name,
            "type" => Map.get(params, "type", "OD"),
            "class_id" => class_id,
            "boat_class_id" => class_id,
            "class" => class_display_name(boat_class),
            "type_handicap" => class_handicap_type(boat_class),
            "handicap_value" => class_handicap_value(boat_class),
            "date" => date,
            "start_time" => Map.get(params, "start_time", ""),
            "course" => Map.get(params, "course", ""),
            "description" => Map.get(params, "description", ""),
            "finished" => false,
            "participants" => []
          }

          case Mongo.insert_one(:mongo, @collection, race) do
            {:ok, result} ->
              json(conn, %{
                message: "Race added",
                id: object_id_to_string(result.inserted_id)
              })

            {:error, reason} ->
              conn
              |> put_status(500)
              |> json(%{error: inspect(reason)})
          end

        {:error, :invalid_object_id} ->
          conn
          |> put_status(400)
          |> json(%{error: "Identifiant de classe invalide"})

        {:error, :class_not_found} ->
          conn
          |> put_status(404)
          |> json(%{error: "Classe de bateau introuvable"})
      end
    else
      :error ->
        conn
        |> put_status(400)
        |> json(%{error: "Missing parameters (name, date)"})
    end
  end

  # DELETE /api/deletrace/:race_id
  def delete_race(conn, %{"race_id" => race_id}) do
    with {:ok, object_id} <- decode_object_id(race_id),
         {:ok, _race} <- get_race_by_id(object_id) do
      case Mongo.delete_one(:mongo, @collection, %{"_id" => object_id}) do
        {:ok, %{deleted_count: 0}} ->
          conn
          |> put_status(404)
          |> json(%{error: "Course introuvable"})

        {:ok, _result} ->
          json(conn, %{message: "Course supprimée"})

        {:error, reason} ->
          conn
          |> put_status(500)
          |> json(%{error: inspect(reason)})
      end
    else
      {:error, :invalid_object_id} ->
        conn
        |> put_status(400)
        |> json(%{error: "race_id invalide"})

      {:error, :race_not_found} ->
        conn
        |> put_status(404)
        |> json(%{error: "Course introuvable"})
    end
  end

  # GET /api/getraces
  def get_races(conn, _params) do
    races =
      Mongo.find(:mongo, @collection, %{})
      |> Enum.map(&serialize_race/1)

    json(conn, races)
  end

  # PUT /api/updaterace/:race_id
  def update_race(conn, %{"race_id" => race_id} = params) do
    with {:ok, object_id} <- decode_object_id(race_id),
         {:ok, existing_race} <- get_race_by_id(object_id) do
      class_id =
        Map.get(params, "class_id") ||
          Map.get(params, "boat_class_id") ||
          existing_race["class_id"] ||
          existing_race["boat_class_id"]

      with :ok <- ensure_class_can_be_modified(existing_race, class_id) do
        case get_optional_class(class_id) do
          {:ok, boat_class} ->
            updates = %{
              "name" => Map.get(params, "name", existing_race["name"] || ""),
              "type" => Map.get(params, "type", existing_race["type"] || "OD"),
              "class_id" => class_id,
              "boat_class_id" => class_id,
              "class" => class_display_name(boat_class),
              "type_handicap" => class_handicap_type(boat_class),
              "handicap_value" => class_handicap_value(boat_class),
              "date" => Map.get(params, "date", existing_race["date"] || ""),
              "start_time" => Map.get(params, "start_time", existing_race["start_time"] || ""),
              "course" => Map.get(params, "course", existing_race["course"] || ""),
              "description" => Map.get(params, "description", existing_race["description"] || "")
            }

            case Mongo.update_one(
                   :mongo,
                   @collection,
                   %{"_id" => object_id},
                   %{"$set" => updates}
                 ) do
              {:ok, _} ->
                json(conn, %{message: "Race updated"})

              {:error, reason} ->
                conn
                |> put_status(500)
                |> json(%{error: inspect(reason)})
            end

          {:error, :invalid_object_id} ->
            conn
            |> put_status(400)
            |> json(%{error: "Identifiant de classe invalide"})

          {:error, :class_not_found} ->
            conn
            |> put_status(404)
            |> json(%{error: "Classe de bateau introuvable"})
        end
      else
        {:error, :cannot_modify_class_with_participants} ->
          conn
          |> put_status(400)
          |> json(%{
            error:
              "Impossible de modifier la classe d'une course qui contient déjà des participants"
          })
      end
    else
      {:error, :invalid_object_id} ->
        conn
        |> put_status(400)
        |> json(%{error: "Invalid race_id"})

      {:error, :race_not_found} ->
        conn
        |> put_status(404)
        |> json(%{error: "Race not found"})
    end
  end

  # PUT /api/setracefinished/:race_id
  def set_race_finished(conn, %{"race_id" => race_id, "finished" => finished}) do
    with {:ok, object_id} <- decode_object_id(race_id),
         {:ok, _race} <- get_race_by_id(object_id) do
      case Mongo.update_one(
             :mongo,
             @collection,
             %{"_id" => object_id},
             %{"$set" => %{"finished" => finished}}
           ) do
        {:ok, _} ->
          json(conn, %{message: "Race status updated", finished: finished})

        {:error, reason} ->
          conn
          |> put_status(500)
          |> json(%{error: inspect(reason)})
      end
    else
      {:error, :invalid_object_id} ->
        conn |> put_status(400) |> json(%{error: "Invalid race_id"})

      {:error, :race_not_found} ->
        conn |> put_status(404) |> json(%{error: "Race not found"})
    end
  end

  # PUT /api/updateraceresults/:race_id
  def update_race_results(conn, %{"race_id" => race_id, "participants" => participants}) do
    with {:ok, object_id} <- decode_object_id(race_id),
         {:ok, _race} <- get_race_by_id(object_id) do
      case Mongo.update_one(
             :mongo,
             @collection,
             %{"_id" => object_id},
             %{"$set" => %{"participants" => participants}}
           ) do
        {:ok, _} ->
          json(conn, %{message: "Race results updated"})

        {:error, reason} ->
          conn
          |> put_status(500)
          |> json(%{error: inspect(reason)})
      end
    else
      {:error, :invalid_object_id} ->
        conn |> put_status(400) |> json(%{error: "Invalid race_id"})

      {:error, :race_not_found} ->
        conn |> put_status(404) |> json(%{error: "Race not found"})
    end
  end

  # POST /api/addparticipanttorace
  def add_participant_to_race(conn, params) do
    with {:ok, race_id} <- Map.fetch(params, "race_id"),
         {:ok, boat_id} <- Map.fetch(params, "boat_id"),
         {:ok, race_object_id} <- decode_object_id(race_id),
         {:ok, boat_object_id} <- decode_object_id(boat_id),
         {:ok, race} <- get_race_by_id(race_object_id),
         {:ok, boat} <- MyappWeb.BoatController.get_boat_by_id(boat_object_id),
         :ok <- ensure_race_not_finished(race),
         :ok <- ensure_boat_matches_race_class(race, boat),
         :ok <- ensure_participant_not_already_registered(race, boat_id, boat["noVoile"]) do
      participant = %{
        "id" => generate_participant_id(),
        "boat_id" => boat_id,
        "boat_name" => boat["nom"],
        "sail_number" => boat["noVoile"],
        "boat_class" => boat["classe"],
        "class_id" => boat["class_id"] || boat["boat_class_id"],
        "boat_class_id" => boat["boat_class_id"] || boat["class_id"],
        "type_handicap" => boat["type_handicap"],
        "handicap_value" => boat["valeur_handicap"],
        "helm_name" => boat["NomBarreur"],
        "result" => nil,
        "position" => nil,
        "points" => nil,
        "inserted_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      }

      case Mongo.update_one(
             :mongo,
             @collection,
             %{"_id" => race_object_id},
             %{"$push" => %{"participants" => participant}}
           ) do
        {:ok, %{matched_count: 0}} ->
          conn |> put_status(404) |> json(%{error: "Race not found"})

        {:ok, _result} ->
          json(conn, %{
            message: "Participant added to race",
            race_id: race_id,
            participant: serialize_participant(participant)
          })

        {:error, reason} ->
          conn |> put_status(500) |> json(%{error: inspect(reason)})
      end
    else
      :error ->
        conn
        |> put_status(400)
        |> json(%{error: "Missing parameters (race_id, boat_id)"})

      {:error, :invalid_object_id} ->
        conn |> put_status(400) |> json(%{error: "Invalid ID"})

      {:error, :race_not_found} ->
        conn |> put_status(404) |> json(%{error: "Race not found"})

      {:error, :boat_not_found} ->
        conn |> put_status(404) |> json(%{error: "Boat not found"})

      {:error, :race_finished} ->
        conn |> put_status(400) |> json(%{error: "Cannot add participant to a finished race"})

      {:error, :participant_already_registered} ->
        conn |> put_status(409) |> json(%{error: "Boat already registered in this race"})

      {:error, :boat_class_not_allowed} ->
        conn
        |> put_status(400)
        |> json(%{error: "Ce bateau ne respecte pas la classe requise pour cette course"})

      {:error, reason} ->
        conn |> put_status(500) |> json(%{error: inspect(reason)})
    end
  end

  # DELETE /api/removeparticipantfromrace/:race_id/:participant_id
  def remove_participant_from_race(conn, %{
        "race_id" => race_id,
        "participant_id" => participant_id
      }) do
    with {:ok, object_id} <- decode_object_id(race_id),
         {:ok, race} <- get_race_by_id(object_id),
         :ok <- ensure_race_not_finished(race),
         {:ok, parsed_participant_id} <- parse_participant_id(participant_id),
         {:ok, participant} <- get_participant_from_race(race, parsed_participant_id) do
      case Mongo.update_one(
             :mongo,
             @collection,
             %{"_id" => object_id},
             %{
               "$pull" => %{
                 "participants" => %{"id" => parsed_participant_id}
               }
             }
           ) do
        {:ok, _result} ->
          remove_participant_from_related_series(race_id, participant)

          json(conn, %{
            message: "Participant retiré de la course et des séries associées",
            race_id: race_id,
            participant_id: parsed_participant_id
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
        |> json(%{error: "race_id invalide"})

      {:error, :race_not_found} ->
        conn
        |> put_status(404)
        |> json(%{error: "Course introuvable"})

      {:error, :race_finished} ->
        conn
        |> put_status(400)
        |> json(%{error: "Impossible de retirer un participant d'une course terminée"})

      {:error, :invalid_participant_id} ->
        conn
        |> put_status(400)
        |> json(%{error: "participant_id invalide"})

      {:error, :participant_not_found} ->
        conn
        |> put_status(404)
        |> json(%{error: "Participant introuvable dans cette course"})
    end
  end

  # GET /api/getparticipantsforrace/:race_id
  def get_participants_for_race(conn, %{"race_id" => race_id}) do
    with {:ok, object_id} <- decode_object_id(race_id),
         {:ok, race} <- get_race_by_id(object_id) do
      participants =
        race
        |> Map.get("participants", [])
        |> Enum.map(&serialize_participant/1)

      json(conn, participants)
    else
      {:error, :invalid_object_id} ->
        conn |> put_status(400) |> json(%{error: "Invalid race_id"})

      {:error, :race_not_found} ->
        conn |> put_status(404) |> json(%{error: "Race not found"})
    end
  end

  defp get_participant_from_race(race, participant_id) do
    participant =
      race
      |> Map.get("participants", [])
      |> Enum.find(fn participant ->
        (participant["id"] || participant[:id]) == participant_id
      end)

    case participant do
      nil -> {:error, :participant_not_found}
      participant -> {:ok, participant}
    end
  end

  defp remove_participant_from_related_series(race_id, participant) do
    boat_id = participant["boat_id"] || participant[:boat_id]

    if is_nil(boat_id) or boat_id == "" do
      :ok
    else
      related_series =
        Mongo.find(:mongo, @series_collection, %{
          "race_ids" => race_id,
          "participants.boat_id" => boat_id
        })
        |> Enum.to_list()

      Enum.each(related_series, fn serie ->
        race_ids = Map.get(serie, "race_ids", [])

        Mongo.update_one(
          :mongo,
          @series_collection,
          %{"_id" => serie["_id"]},
          %{"$pull" => %{"participants" => %{"boat_id" => boat_id}}}
        )

        Enum.each(race_ids, fn linked_race_id ->
          with {:ok, linked_race_object_id} <- decode_object_id(linked_race_id) do
            Mongo.update_one(
              :mongo,
              @collection,
              %{"_id" => linked_race_object_id},
              %{"$pull" => %{"participants" => %{"boat_id" => boat_id}}}
            )
          else
            _ -> :ok
          end
        end)
      end)

      :ok
    end
  end

  defp serialize_race(race) do
    %{
      id: object_id_to_string(race["_id"]),
      name: race["name"] || "",
      type: race["type"] || "OD",
      class: race["class"] || "",
      class_id: race["class_id"] || race["boat_class_id"],
      boat_class_id: race["boat_class_id"] || race["class_id"],
      type_handicap: race["type_handicap"],
      handicap_value: race["handicap_value"],
      date: race["date"] || "",
      start_time: race["start_time"] || "",
      course: race["course"] || "",
      description: race["description"] || "",
      finished: Map.get(race, "finished", false),
      participants: Enum.map(Map.get(race, "participants", []), &serialize_participant/1)
    }
  end

  defp serialize_participant(participant) do
    %{
      id: participant["id"] || participant[:id],
      boat_id: participant["boat_id"] || participant[:boat_id],
      boat_name: participant["boat_name"] || participant[:boat_name] || "",
      sail_number: participant["sail_number"] || participant[:sail_number] || "",
      boat_class: participant["boat_class"] || participant[:boat_class] || "",
      class_id:
        participant["class_id"] || participant[:class_id] || participant["boat_class_id"] ||
          participant[:boat_class_id],
      boat_class_id:
        participant["boat_class_id"] || participant[:boat_class_id] || participant["class_id"] ||
          participant[:class_id],
      type_handicap: participant["type_handicap"] || participant[:type_handicap],
      handicap_value: participant["handicap_value"] || participant[:handicap_value],
      helm_name: participant["helm_name"] || participant[:helm_name] || "",
      result: participant["result"] || participant[:result],
      position: participant["position"] || participant[:position],
      points: participant["points"] || participant[:points],
      inserted_at: participant["inserted_at"] || participant[:inserted_at]
    }
  end

  defp object_id_to_string(%BSON.ObjectId{} = object_id) do
    BSON.ObjectId.encode!(object_id)
  end

  defp object_id_to_string(value), do: value

  defp decode_object_id(id) when is_binary(id) do
    try do
      {:ok, BSON.ObjectId.decode!(id)}
    rescue
      _ -> {:error, :invalid_object_id}
    end
  end

  defp get_race_by_id(object_id) do
    case Mongo.find_one(:mongo, @collection, %{"_id" => object_id}) do
      nil -> {:error, :race_not_found}
      race -> {:ok, race}
    end
  end

  defp ensure_race_not_finished(race) do
    if Map.get(race, "finished", false) do
      {:error, :race_finished}
    else
      :ok
    end
  end

  defp ensure_participant_not_already_registered(race, boat_id, sail_number) do
    participants = Map.get(race, "participants", [])

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

  defp generate_participant_id do
    System.unique_integer([:positive, :monotonic])
  end

  defp parse_participant_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {parsed_id, ""} -> {:ok, parsed_id}
      _ -> {:error, :invalid_participant_id}
    end
  end

  defp ensure_class_can_be_modified(existing_race, new_class_id) do
    old_class_id = existing_race["class_id"] || existing_race["boat_class_id"]
    participants = Map.get(existing_race, "participants", [])

    class_changed? = old_class_id != new_class_id
    has_participants? = length(participants) > 0

    if class_changed? and has_participants? do
      {:error, :cannot_modify_class_with_participants}
    else
      :ok
    end
  end

  defp get_optional_class(nil), do: {:ok, nil}
  defp get_optional_class(""), do: {:ok, nil}

  defp get_optional_class(class_id) do
    with {:ok, object_id} <- decode_object_id(class_id),
         {:ok, boat_class} <- get_class_by_id(object_id) do
      {:ok, boat_class}
    end
  end

  defp get_class_by_id(object_id) do
    case Mongo.find_one(:mongo, @classes_collection, %{"_id" => object_id}) do
      nil -> {:error, :class_not_found}
      boat_class -> {:ok, boat_class}
    end
  end

  defp class_display_name(nil), do: ""
  defp class_display_name(boat_class), do: boat_class["display_name"] || boat_class["name"] || ""

  defp class_handicap_type(nil), do: nil
  defp class_handicap_type(boat_class), do: boat_class["handicap_type"]

  defp class_handicap_value(nil), do: nil
  defp class_handicap_value(boat_class), do: boat_class["handicap_value"]

  defp ensure_boat_matches_race_class(race, boat) do
    race_class_id = race["class_id"] || race["boat_class_id"]

    if is_nil(race_class_id) or race_class_id == "" do
      :ok
    else
      boat_class_id = boat["class_id"] || boat["boat_class_id"]

      if boat_class_id == race_class_id do
        :ok
      else
        {:error, :boat_class_not_allowed}
      end
    end
  end
end
