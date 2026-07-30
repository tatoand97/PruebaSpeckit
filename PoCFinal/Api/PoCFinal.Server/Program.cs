using Azure.Identity;
using Common.Presentation.ExceptionHandling;
using ContactRequests.Application.RegisterContactRequest;
using ContactRequests.Infrastructure.Persistence;
using ContactRequests.Presentation;
using FluentValidation;
using Microsoft.EntityFrameworkCore;
using OpenTelemetry.Metrics;
using OpenTelemetry.Trace;
using Wolverine;
using Wolverine.Runtime;

var builder = WebApplication.CreateBuilder(args);

var appConfigEndpoint = builder.Configuration["AzureAppConfiguration:Endpoint"];
if (!string.IsNullOrWhiteSpace(appConfigEndpoint))
{
    builder.Configuration.AddAzureAppConfiguration(options =>
        options.Connect(new Uri(appConfigEndpoint), new DefaultAzureCredential()));
}

builder.Services.AddProblemDetails();
builder.Services.AddExceptionHandler<GlobalExceptionHandler>();
builder.Services.AddHealthChecks();
builder.Services.AddValidatorsFromAssembly(typeof(RegisterContactRequestValidator).Assembly);
builder.Services.AddContactRequestsModule();

builder.Services.AddOpenTelemetry()
    .WithTracing(tracing => tracing.AddAspNetCoreInstrumentation().AddConsoleExporter())
    .WithMetrics(metrics => metrics.AddAspNetCoreInstrumentation().AddConsoleExporter());

builder.Services.AddDbContext<ContactRequestsDbContext>(options =>
{
    var connectionString = builder.Configuration.GetConnectionString("ContactRequests")
                           ?? "Server=(localdb)\\MSSQLLocalDB;Database=PoCFinalContactRequests;Trusted_Connection=True;Encrypt=False";

    options.UseSqlServer(connectionString);
});

builder.Host.UseWolverine(options =>
{
    options.Durability.Mode = DurabilityMode.MediatorOnly;
});

var app = builder.Build();

app.UseExceptionHandler();
app.MapHealthChecks("/health");
app.MapContactRequestsModule();

app.Run();
