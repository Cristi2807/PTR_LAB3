# Use the official Elixir image as the base image
FROM elixir:latest

# Set the working directory inside the container
WORKDIR /app

# Copy the mix.exs and mix.lock files to the container
COPY mix.exs mix.lock ./

# Install dependencies
RUN mix local.hex --force && mix local.rebar --force
RUN mix deps.get

# Copy the rest of the application files to the container
COPY . .

# Build the application
RUN mix compile

# Expose ports 4040 and 8080
EXPOSE 4040 8080

# Start the application
CMD ["mix", "run", "--no-halt"]