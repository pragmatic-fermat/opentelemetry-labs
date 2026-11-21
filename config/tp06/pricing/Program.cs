// Service .NET minimal : une API qui repond au prix.
var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/price", () => Results.Json(new { currency = "EUR", amount = 12.5 }));

app.Run("http://0.0.0.0:8082");
