defmodule MyappWeb.UserController do
  use MyappWeb, :controller
  use PhoenixSwagger
  alias Mongo

  @collection "users"
  @token_salt "user_auth"

  swagger_path :get_test do
    get("/getTest")
    summary("Tester l'API")
    description("Retourne un message simple pour vérifier que l'API fonctionne")

    response(200, "API fonctionnelle", Schema.ref(:MessageResponse))
    security([%{"Bearer" => []}])
  end

  swagger_path :register do
    post("/register")
    summary("Inscription")
    description("Crée un nouvel utilisateur")
    consumes("application/json")

    parameter(:body, :body, Schema.ref(:RegisterInput), "Informations d'inscription",
      required: true
    )

    response(201, "Inscription réussie", Schema.ref(:AuthSuccessResponse))
    response(400, "Données invalides", Schema.ref(:Error))
    response(409, "Utilisateur déjà existant", Schema.ref(:Error))
    response(500, "Erreur serveur", Schema.ref(:ErrorWithDetails))
  end

  swagger_path :login do
    post("/login")
    summary("Connexion")
    description("Connecte un utilisateur existant")
    consumes("application/json")

    parameter(:body, :body, Schema.ref(:LoginInput), "Informations de connexion", required: true)

    response(200, "Connexion réussie", Schema.ref(:AuthSuccessResponse))
    response(400, "Données invalides", Schema.ref(:Error))
    response(401, "Identifiants invalides", Schema.ref(:Error))
    response(500, "Erreur serveur", Schema.ref(:Error))
  end

  def swagger_definitions do
    %{
      RegisterInput:
        swagger_schema do
          title("RegisterInput")
          description("Données requises pour inscrire un utilisateur")

          properties do
            username(:string, "Nom d'utilisateur", required: true)
            password(:string, "Mot de passe", required: true)
          end

          example(%{
            username: "mirko",
            password: "123123"
          })
        end,
      LoginInput:
        swagger_schema do
          title("LoginInput")
          description("Données requises pour connecter un utilisateur")

          properties do
            username(:string, "Nom d'utilisateur", required: true)
            password(:string, "Mot de passe", required: true)
          end

          example(%{
            username: "mirko",
            password: "123123"
          })
        end,
      User:
        swagger_schema do
          title("User")
          description("Utilisateur authentifié")

          properties do
            id(:string, "ID utilisateur")
            username(:string, "Nom d'utilisateur")
          end

          example(%{
            id: "67f123456789abcdef123456",
            username: "mirko"
          })
        end,
      AuthSuccessResponse:
        swagger_schema do
          title("AuthSuccessResponse")
          description("Réponse de succès après inscription ou connexion")

          properties do
            message(:string, "Message de succès")
            user(Schema.ref(:User), "Utilisateur")
            token(:string, "Jeton d'authentification")
          end

          example(%{
            message: "Connexion réussie",
            user: %{
              id: "67f123456789abcdef123456",
              username: "mirko"
            },
            token: "eyJhbGciOiJIUzI1NiJ9..."
          })
        end,
      MessageResponse:
        swagger_schema do
          title("MessageResponse")
          description("Réponse simple avec message")

          properties do
            message(:string, "Message")
          end

          example(%{
            message: "API fonctionnelle"
          })
        end,
      Error:
        swagger_schema do
          title("Error")
          description("Réponse d'erreur")

          properties do
            error(:string, "Message d'erreur")
          end

          example(%{
            error: "Le mot de passe est obligatoire"
          })
        end,
      ErrorWithDetails:
        swagger_schema do
          title("ErrorWithDetails")
          description("Réponse d'erreur avec détails")

          properties do
            error(:string, "Message d'erreur")
            details(:string, "Détails")
          end

          example(%{
            error: "Erreur serveur lors de l'inscription",
            details: "some internal error"
          })
        end
    }
  end

  # GET /api/getTest
  def get_test(conn, _params) do
    json(conn, %{message: "API fonctionnelle"})
  end

  # POST /api/register
  def register(conn, params) do
    with {:ok, username} <- fetch_required_string(params, "username"),
         {:ok, password} <- fetch_required_string(params, "password"),
         :ok <- validate_username(username),
         :ok <- validate_password(password) do
      normalized_username = normalize_username(username)

      existing_user =
        Mongo.find_one(:mongo, @collection, %{"username" => normalized_username})

      if existing_user do
        conn
        |> put_status(409)
        |> json(%{error: "Cet utilisateur existe déjà"})
      else
        password_hash = Pbkdf2.hash_pwd_salt(password)

        user = %{
          "username" => normalized_username,
          "password_hash" => password_hash,
          "inserted_at" => DateTime.utc_now() |> DateTime.to_iso8601()
        }

        case Mongo.insert_one(:mongo, @collection, user) do
          {:ok, result} ->
            user_id = object_id_to_string(result.inserted_id)
            token = Phoenix.Token.sign(MyappWeb.Endpoint, @token_salt, user_id)

            conn
            |> put_status(201)
            |> json(%{
              message: "Inscription réussie",
              user: %{
                "id" => user_id,
                "username" => normalized_username
              },
              token: token
            })

          {:error, reason} ->
            conn
            |> put_status(500)
            |> json(%{
              error: "Erreur serveur lors de l'inscription",
              details: inspect(reason)
            })
        end
      end
    else
      {:error, message} ->
        conn
        |> put_status(400)
        |> json(%{error: message})
    end
  end

  # POST /api/login
  def login(conn, params) do
    with {:ok, username} <- fetch_required_string(params, "username"),
         {:ok, password} <- fetch_required_string(params, "password") do
      normalized_username = normalize_username(username)

      user =
        Mongo.find_one(:mongo, @collection, %{"username" => normalized_username})

      cond do
        is_nil(user) ->
          conn
          |> put_status(401)
          |> json(%{error: "Nom d'utilisateur ou mot de passe invalide"})

        is_nil(user["password_hash"]) ->
          conn
          |> put_status(500)
          |> json(%{error: "Utilisateur invalide en base de données"})

        Pbkdf2.verify_pass(password, user["password_hash"]) ->
          user_id = object_id_to_string(user["_id"])
          token = Phoenix.Token.sign(MyappWeb.Endpoint, @token_salt, user_id)

          json(conn, %{
            message: "Connexion réussie",
            user: %{
              "id" => user_id,
              "username" => user["username"]
            },
            token: token
          })

        true ->
          conn
          |> put_status(401)
          |> json(%{error: "Nom d'utilisateur ou mot de passe invalide"})
      end
    else
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

  defp field_required_message("username"), do: "Le nom d'utilisateur est obligatoire"
  defp field_required_message("password"), do: "Le mot de passe est obligatoire"
  defp field_required_message(field), do: "Le champ #{field} est obligatoire"

  defp normalize_username(username) do
    username
    |> String.trim()
    |> String.downcase()
  end

  defp validate_username(username) do
    normalized = normalize_username(username)

    cond do
      String.length(normalized) < 3 ->
        {:error, "Le nom d'utilisateur doit contenir au moins 3 caractères"}

      String.length(normalized) > 25 ->
        {:error, "Le nom d'utilisateur doit contenir au maximum 25 caractères"}

      not Regex.match?(~r/^[a-z0-9_-]+$/, normalized) ->
        {:error,
         "Le nom d'utilisateur ne peut contenir que des lettres minuscules, chiffres, _ et -"}

      true ->
        :ok
    end
  end

  defp validate_password(password) do
    cond do
      String.length(password) < 6 ->
        {:error, "Le mot de passe doit contenir au moins 6 caractères"}

      String.length(password) > 128 ->
        {:error, "Le mot de passe est trop long"}

      true ->
        :ok
    end
  end

  defp object_id_to_string(%BSON.ObjectId{} = object_id) do
    BSON.ObjectId.encode!(object_id)
  end

  defp object_id_to_string(value), do: value
end
