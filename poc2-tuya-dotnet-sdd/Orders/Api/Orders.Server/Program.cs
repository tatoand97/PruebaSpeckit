using Common.Presentation;
using Orders.Presentation;
using Serilog;
using Wolverine;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((context, services, loggerConfiguration) =>
    loggerConfiguration
        .ReadFrom.Configuration(context.Configuration)
        .ReadFrom.Services(services)
        .Enrich.FromLogContext());

builder.AddPlatformObservability();
builder.Services.AddOrdersModule(builder.Configuration);
builder.Services.AddCommonPresentation();

builder.Host.UseWolverine(options =>
{
    options.Durability.Mode = DurabilityMode.MediatorOnly;
    options.Discovery.IncludeAssembly(OrdersModule.ApplicationAssembly);
});

var app = builder.Build();

app.UseExceptionHandler();
app.UseSerilogRequestLogging();

app.MapOrdersModule();
app.MapHealthChecks("/health");

app.Run();

public partial class Program;
