# Stage 1: Build
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build

WORKDIR /build

COPY src/ ./src/

RUN dotnet restore src/Starter.WebApi.slnx

RUN dotnet publish src/Host/Starter.WebApi/Starter.WebApi.csproj -c Release --no-restore -o /publish

# Stage 2: Runtime
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime

WORKDIR /app

COPY --from=build /publish .

RUN apt-get update \
    && apt-get install -y --no-install-recommends wget \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /data && chown -R app:app /app /data

USER app

ENV ASPNETCORE_URLS=http://+:8080 \
    ASPNETCORE_ENVIRONMENT=Production \
    DOTNET_RUNNING_IN_CONTAINER=true

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD wget -qO- http://localhost:8080/health/live || exit 1

ENTRYPOINT ["dotnet", "Starter.WebApi.dll"]
