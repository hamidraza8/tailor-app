FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

COPY src/TailorShop.Domain/TailorShop.Domain.csproj src/TailorShop.Domain/
COPY src/TailorShop.Infrastructure/TailorShop.Infrastructure.csproj src/TailorShop.Infrastructure/
COPY src/TailorShop.Application/TailorShop.Application.csproj src/TailorShop.Application/
COPY src/TailorShop.Api/TailorShop.Api.csproj src/TailorShop.Api/
RUN dotnet restore src/TailorShop.Api/TailorShop.Api.csproj

COPY . .
RUN dotnet publish src/TailorShop.Api/TailorShop.Api.csproj -c Release -o /app/publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

# Install libgdiplus for QuestPDF
RUN apt-get update && apt-get install -y libgdiplus && rm -rf /var/lib/apt/lists/*

COPY --from=build /app/publish .

RUN mkdir -p /app/uploads

EXPOSE 5000
ENV ASPNETCORE_URLS=http://+:5000
ENTRYPOINT ["dotnet", "TailorShop.Api.dll"]
