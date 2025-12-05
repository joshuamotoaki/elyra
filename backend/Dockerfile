ARG ELIXIR_VERSION=1.18
ARG OTP_VERSION=27
ARG ALPINE_VERSION=3.20

FROM elixir:${ELIXIR_VERSION}-otp-${OTP_VERSION}-alpine AS build
WORKDIR /app
RUN apk add --no-cache build-base git
RUN mix local.hex --force && \
    mix local.rebar --force
ENV MIX_ENV=dev
COPY mix.exs mix.lock ./
RUN mix deps.get
COPY . .
RUN mix compile
EXPOSE 4000
CMD ["mix", "phx.server"]
