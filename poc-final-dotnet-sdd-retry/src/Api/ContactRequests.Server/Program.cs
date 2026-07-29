using Common.Infrastructure.Configuration;
using Common.Infrastructure.Observability;
using Common.Presentation;
using ContactRequests.Presentation;
using ContactRequests.Presentation.Messaging;
using ContactRequests.Server.Health;
using JasperFx.CodeGeneration;
using Serilog;
using Wolverine;
using Wolverine.Configuration;

var builder = WebApplication.CreateBuilder(args);

builder.Configuration.AddConditionalAzureAppConfiguration();

builder.Host.UseSerilog((context, services, loggerConfiguration) =>
    loggerConfiguration
        .ReadFrom.Configuration(context.Configuration)
        .ReadFrom.Services(services)
        .Enrich.FromLogContext()
        .WriteTo.Console());

builder.Services.AddProblemDetails();
builder.Services.AddContactRequestsObservability();
builder.Services.AddContactRequestsModule(builder.Configuration);
builder.Services.AddCommonPresentation();

builder.Services.AddWolverine(options =>
{
    options.Durability.Mode = DurabilityMode.MediatorOnly;
    options.CodeGeneration.TypeLoadMode = TypeLoadMode.Static;
    options.UseContactRequestsMediatorHandlers();
});

var app = builder.Build();

app.UseExceptionHandler();
app.UseSerilogRequestLogging(options =>
{
    options.MessageTemplate =
        "HTTP {RequestMethod} responded {StatusCode} in {Elapsed:0.0000} ms";
});

app.MapContactRequestsModule();
app.MapContactRequestsHealth();

await app.RunAsync();
