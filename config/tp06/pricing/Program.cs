// Service .NET minimal : une API qui repond au prix.
var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

var http = new HttpClient();

app.MapGet("/price", async () =>
{
    object? shipping = null;
    try
    {
        shipping = await http.GetFromJsonAsync<object>("http://localhost:8083/ship");
    }
    catch (Exception e)
    {
        shipping = new { error = e.GetType().Name };
    }
    return Results.Json(new { currency = "EUR", amount = 12.5, shipping });
});

app.Run("http://0.0.0.0:8082");
