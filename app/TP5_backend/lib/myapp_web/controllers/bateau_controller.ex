defmodule MyappWeb.BoatController do
  use MyappWeb, :controller
  use PhoenixSwagger
  alias Mongo

  @collection "boats"
  @races_collection "races"
  @classes_collection "boat_classes"

  swagger_path :add_boat do
    post("/addboat")
    summary("Ajouter un bateau")
    description("Ajoute un nouveau bateau")
    consumes("application/json")

    parameter(:body, :body, Schema.ref(:BoatInput), "Informations du bateau", required: true)

    response(200, "Bateau ajouté", Schema.ref(:BoatCreateResponse))
    response(400, "Paramètres manquants", Schema.ref(:Error))
    response(500, "Erreur serveur", Schema.ref(:Error))

    security([%{"Bearer" => []}])
  end

  swagger_path :get_boats do
    get("/getboats")
    summary("Lister les bateaux")
    description("Retourne la liste des bateaux")

    response(200, "Liste des bateaux", Schema.array(:Boat))
    response(500, "Erreur serveur", Schema.ref(:Error))

    security([%{"Bearer" => []}])
  end

  swagger_path :update_boat do
    put("/updateboat/{boat_id}")
    summary("Modifier un bateau")
    description("Met à jour un bateau existant")
    consumes("application/json")

    parameter(:boat_id, :path, :string, "ID du bateau", required: true)

    parameter(:body, :body, Schema.ref(:BoatInput), "Nouvelles informations du bateau",
      required: true
    )

    response(200, "Bateau modifié")
    response(400, "Paramètres invalides", Schema.ref(:Error))
    response(404, "Bateau introuvable", Schema.ref(:Error))
    response(500, "Erreur serveur", Schema.ref(:Error))

    security([%{"Bearer" => []}])
  end

  swagger_path :delete_boat do
    delete("/deleteboat/{boat_id}")
    summary("Supprimer un bateau")

    description(
      "Supprime un bateau seulement s’il n’est inscrit à aucune course. " <>
        "Si le bateau est déjà inscrit à une ou plusieurs courses, la suppression est refusée."
    )

    parameter(:boat_id, :path, :string, "ID du bateau", required: true)

    response(200, "Bateau supprimé")
    response(400, "ID invalide", Schema.ref(:Error))
    response(404, "Bateau introuvable", Schema.ref(:Error))
    response(409, "Bateau déjà inscrit à une ou plusieurs courses", Schema.ref(:Error))
    response(500, "Erreur serveur", Schema.ref(:Error))

    security([%{"Bearer" => []}])
  end

  def swagger_definitions do
    %{
      Boat:
        swagger_schema do
          title("Boat")
          description("Représentation d'un bateau")

          properties do
            id(:string, "ID du bateau")
            nom(:string, "Nom du bateau")
            noVoile(:string, "Numéro de voile")
            classe(:string, "Classe du bateau")
            nomBarreur(:string, "Nom du barreur")
          end

          example(%{
            id: "67f123456789abcdef123456",
            nom: "Le Vent Rapide",
            noVoile: "QC123",
            classe: "Laser",
            NomBarreur: "Mirko Brlek"
          })
        end,
      BoatInput:
        swagger_schema do
          title("BoatInput")
          description("Données requises pour créer ou modifier un bateau")

          properties do
            nomBateau(:string, "Nom du bateau", required: true)
            numeroVoile(:string, "Numéro de voile", required: true)
            class_id(:string, "ID de la classe de bateau", required: true)
            nomBarreur(:string, "Nom du barreur", required: true)
          end

          example(%{
            nomBateau: "Le Vent Rapide",
            numeroVoile: "QC123",
            class_id: "67f123456789abcdef123456",
            nomBarreur: "Mirko Brlek"
          })
        end,
      BoatCreateResponse:
        swagger_schema do
          title("BoatCreateResponse")
          description("Réponse après création d'un bateau")

          properties do
            message(:string, "Message de succès")
            id(:string, "ID du bateau créé")
          end

          example(%{
            message: "Boat added",
            id: "67f123456789abcdef123456"
          })
        end,
      Error:
        swagger_schema do
          title("Error")
          description("Réponse d'erreur")

          properties do
            error(:string, "Message d'erreur")
            details(:string, "Détails optionnels")
          end

          example(%{
            error: "Boat not found"
          })
        end
    }
  end

  # POST /api/addboat
  def add_boat(conn, params) do
    nom = Map.get(params, "nomBateau")
    numero_voile = Map.get(params, "numeroVoile")
    class_id = Map.get(params, "class_id") || Map.get(params, "boat_class_id")
    barreur = Map.get(params, "nomBarreur")

    if nom && numero_voile && class_id && barreur do
      with {:ok, class_object_id} <- decode_object_id(class_id),
           {:ok, boat_class} <- get_class_by_id(class_object_id) do
        boat = %{
          "nom" => nom,
          "noVoile" => numero_voile,
          "class_id" => class_id,
          "boat_class_id" => class_id,
          "classe" => boat_class["display_name"] || boat_class["name"],
          "type_handicap" => boat_class["handicap_type"],
          "valeur_handicap" => boat_class["handicap_value"],
          "NomBarreur" => barreur
        }

        case Mongo.insert_one(:mongo, @collection, boat) do
          {:ok, result} ->
            json(conn, %{
              message: "Boat added",
              id: BSON.ObjectId.encode!(result.inserted_id)
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
          |> json(%{error: "Identifiant de classe invalide"})

        {:error, :class_not_found} ->
          conn
          |> put_status(404)
          |> json(%{error: "Classe de bateau introuvable"})
      end
    else
      conn
      |> put_status(400)
      |> json(%{error: "Missing parameters (nomBateau, numeroVoile, class_id, nomBarreur)"})
    end
  end

  # GET /api/getboats
  def get_boats(conn, _params) do
    boats =
      Mongo.find(:mongo, @collection, %{})
      |> Enum.map(fn boat ->
        %{
          id: BSON.ObjectId.encode!(boat["_id"]),
          nom: boat["nom"],
          noVoile: boat["noVoile"],
          classe: boat["classe"],
          class_id: boat["class_id"] || boat["boat_class_id"],
          boat_class_id: boat["boat_class_id"] || boat["class_id"],
          typeHandicap: boat["type_handicap"],
          valeurHandicap: boat["valeur_handicap"],
          NomBarreur: boat["NomBarreur"]
        }
      end)

    json(conn, boats)
  end

  # PUT /api/updateboat/:boat_id
  def update_boat(conn, %{"boat_id" => boat_id} = params) do
    nom = Map.get(params, "nomBateau")
    numero_voile = Map.get(params, "numeroVoile")
    class_id = Map.get(params, "class_id") || Map.get(params, "boat_class_id")
    barreur = Map.get(params, "nomBarreur")

    if nom && numero_voile && class_id && barreur do
      with {:ok, object_id} <- decode_object_id(boat_id),
           {:ok, _boat} <- get_boat_by_id(object_id),
           {:ok, class_object_id} <- decode_object_id(class_id),
           {:ok, boat_class} <- get_class_by_id(class_object_id) do
        updates = %{
          "nom" => nom,
          "noVoile" => numero_voile,
          "class_id" => class_id,
          "boat_class_id" => class_id,
          "classe" => boat_class["display_name"] || boat_class["name"],
          "NomBarreur" => barreur,
          "type_handicap" => boat_class["handicap_type"],
          "valeur_handicap" => boat_class["handicap_value"]
        }

        case Mongo.update_one(
               :mongo,
               @collection,
               %{"_id" => object_id},
               %{"$set" => updates}
             ) do
          {:ok, _result} ->
            json(conn, %{message: "Boat updated"})

          {:error, reason} ->
            conn
            |> put_status(500)
            |> json(%{error: inspect(reason)})
        end
      else
        {:error, :invalid_object_id} ->
          conn
          |> put_status(400)
          |> json(%{error: "Invalid boat_id or class_id"})

        {:error, :boat_not_found} ->
          conn
          |> put_status(404)
          |> json(%{error: "Boat not found"})

        {:error, :class_not_found} ->
          conn
          |> put_status(404)
          |> json(%{error: "Classe de bateau introuvable"})
      end
    else
      conn
      |> put_status(400)
      |> json(%{error: "Missing parameters (nomBateau, numeroVoile, class_id, nomBarreur)"})
    end
  end

  # DELETE /api/deleteboat/:boat_id
  def delete_boat(conn, %{"boat_id" => boat_id}) do
    with {:ok, object_id} <- decode_object_id(boat_id),
         {:ok, _boat} <- get_boat_by_id(object_id),
         :ok <- ensure_boat_not_registered_in_races(boat_id) do
      case Mongo.delete_one(:mongo, @collection, %{"_id" => object_id}) do
        {:ok, %{deleted_count: 0}} ->
          conn
          |> put_status(404)
          |> json(%{error: "Boat not found"})

        {:ok, _result} ->
          json(conn, %{message: "Boat deleted successfully"})

        {:error, reason} ->
          conn
          |> put_status(500)
          |> json(%{error: inspect(reason)})
      end
    else
      {:error, :invalid_object_id} ->
        conn
        |> put_status(400)
        |> json(%{error: "Invalid boat_id"})

      {:error, :boat_not_found} ->
        conn
        |> put_status(404)
        |> json(%{error: "Boat not found"})

      {:error, :boat_already_registered} ->
        conn
        |> put_status(409)
        |> json(%{
          error:
            "Impossible de supprimer le bateau, puisqu'il est inscrit à une ou plusieurs courses"
        })

      {:error, reason} ->
        conn
        |> put_status(500)
        |> json(%{error: inspect(reason)})
    end
  end

  defp ensure_boat_not_registered_in_races(boat_id) do
    case Mongo.find_one(:mongo, @races_collection, %{"participants.boat_id" => boat_id}) do
      nil ->
        :ok

      _race ->
        {:error, :boat_already_registered}
    end
  end

  defp decode_object_id(id) when is_binary(id) do
    try do
      {:ok, BSON.ObjectId.decode!(id)}
    rescue
      _ -> {:error, :invalid_object_id}
    end
  end

  def get_boat_by_id(object_id) do
    case Mongo.find_one(:mongo, @collection, %{"_id" => object_id}) do
      nil -> {:error, :boat_not_found}
      boat -> {:ok, boat}
    end
  end

  defp get_class_by_id(object_id) do
    case Mongo.find_one(:mongo, @classes_collection, %{"_id" => object_id}) do
      nil -> {:error, :class_not_found}
      boat_class -> {:ok, boat_class}
    end
  end
end
