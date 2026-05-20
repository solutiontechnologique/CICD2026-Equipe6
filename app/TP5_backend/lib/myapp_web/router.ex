defmodule MyappWeb.Router do
  use MyappWeb, :router
  use PhoenixSwagger

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MyappWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug CORSPlug,
      origin: ["http://localhost:5173"],
      methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
      headers: ["Authorization", "Content-Type", "Accept"],
      max_age: 86400

    plug :accepts, ["json"]
  end

  pipeline :api_auth do
    plug MyappWeb.Plugs.AuthPlug
  end

  scope "/", MyappWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/" do
    pipe_through :browser

    forward "/swagger", PhoenixSwagger.Plug.SwaggerUI,
      otp_app: :myapp,
      swagger_file: "swagger.json"
  end

  scope "/api", MyappWeb do
    pipe_through :api

    post "/register", UserController, :register
    post "/login", UserController, :login

    get "/backup", BackupController, :download
  end

  scope "/api", MyappWeb do
    pipe_through [:api, :api_auth]

    post "/addboat", BoatController, :add_boat
    get "/getboats", BoatController, :get_boats
    delete "/deleteboat/:boat_id", BoatController, :delete_boat
    put "/updateboat/:boat_id", BoatController, :update_boat

    post "/addrace", RaceController, :add_race
    get "/getraces", RaceController, :get_races
    delete "/deleterace/:race_id", RaceController, :delete_race
    put "/updaterace/:race_id", RaceController, :update_race
    put "/setracefinished/:race_id", RaceController, :set_race_finished
    put "/updateraceresults/:race_id", RaceController, :update_race_results

    post "/addparticipanttorace", RaceController, :add_participant_to_race
    get "/getparticipantsforrace/:race_id", RaceController, :get_participants_for_race

    delete "/removeparticipantfromrace/:race_id/:participant_id",
           RaceController,
           :remove_participant_from_race

    get "/getSeries", SeriesController, :get_series
    post "/series", SeriesController, :create_serie
    put "/series/:id", SeriesController, :update_serie
    delete "/series/:id", SeriesController, :delete_serie
    put "/series/:id/addRace", SeriesController, :add_race_to_serie
    put "/series/:id/removeRace", SeriesController, :remove_race_from_serie
    post "/addparticipanttoserie", SeriesController, :add_participant_to_serie

    delete "/removeparticipantfromserie/:serie_id/:boat_id",
           SeriesController,
           :remove_participant_from_serie

    get "/classes", ClassesController, :get_classes
    post "/classes", ClassesController, :add_class
    put "/classes/:class_id", ClassesController, :update_class
    delete "/classes/:class_id", ClassesController, :delete_class
  end

  def swagger_info do
    %{
      info: %{
        version: "1.0",
        title: "YRR API"
      },
      basePath: "/api",
      schemes: ["http"],
      consumes: ["application/json"],
      produces: ["application/json"],
      securityDefinitions: %{
        Bearer: %{
          type: "apiKey",
          name: "Authorization",
          in: "header",
          description: "Entrer exactement: Bearer <token>"
        }
      },
      security: [
        %{"Bearer" => []}
      ]
    }
  end
end
