FROM elixir:1.15

RUN apt-get update -y && apt-get install -y \
    build-essential \
    git \
    nodejs \
    npm \
    inotify-tools \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get

COPY . .

EXPOSE 4000

CMD ["sh", "-c", "mix deps.get && mix phx.server"]