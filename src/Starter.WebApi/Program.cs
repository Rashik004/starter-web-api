using Starter.ExceptionHandling;

var builder = WebApplication.CreateBuilder(args);

// --- Observability ---
// (Phase 2: Serilog structured logging)

// --- Security ---
// (Phase 4: Identity + Google OAuth + JWT Bearer)

// --- Data ---
// (Phase 3: EF Core + SQLite)

// --- API ---
builder.Services.AddControllers();
builder.Services.AddAppExceptionHandling();

var app = builder.Build();

// --- Middleware Pipeline ---
app.UseAppExceptionHandling(); // Must be first
app.UseHttpsRedirection();

// (Phase 2: app.UseSerilogRequestLogging())
// (Phase 4: app.UseAuthentication(), app.UseAuthorization())

app.MapControllers();

app.Run();
