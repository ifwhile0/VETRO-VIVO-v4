using Microsoft.EntityFrameworkCore;
using VetroVivo.Data;

var builder = WebApplication.CreateBuilder(args);

// 1. Configura o Banco de Dados (Substitua pela sua string de conexão)
builder.Services.AddDbContext<VetroVivoContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

// 2. Libera o acesso para o seu Frontend
builder.Services.AddCors(options => {
    options.AddDefaultPolicy(policy => {
        policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod();
    });
});

builder.Services.AddControllers();
var app = builder.Build();

app.UseCors();
app.MapControllers();
app.Run();