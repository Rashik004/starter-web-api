# Stage 1: Build
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build

WORKDIR /build

COPY src/ ./src/

# Project-scoped restore: pulls only the host project + its transitive module
# references. Avoids restoring the three test projects (xunit, NetArchTest,
# Mvc.Testing, FluentAssertions) which never reach the runtime image.
RUN dotnet restore src/Host/Starter.WebApi/Starter.WebApi.csproj

RUN dotnet publish src/Host/Starter.WebApi/Starter.WebApi.csproj -c Release --no-restore -o /publish

# Stage 2: Runtime
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime

WORKDIR /app

RUN mkdir -p /data && chown -R app:app /app /data

USER app

COPY --chown=app:app --from=build /publish .

ENV ASPNETCORE_URLS=http://+:8080 \
    ASPNETCORE_ENVIRONMENT=Production \
    DOTNET_RUNNING_IN_CONTAINER=true

EXPOSE 8080

# Self-contained healthcheck: bash + /dev/tcp builtin, no apt-installed binaries.
# The aspnet base image ships bash; /dev/tcp is a bash feature, not a real device.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD bash -c '(exec 3<>/dev/tcp/localhost/8080 && printf "GET /health/live HTTP/1.0\r\nHost: localhost\r\n\r\n" >&3 && head -1 <&3 | grep -q " 200 ") || exit 1'

ENTRYPOINT ["dotnet", "Starter.WebApi.dll"]
