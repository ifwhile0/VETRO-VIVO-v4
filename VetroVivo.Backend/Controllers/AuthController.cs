using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using VetroVivo.Data;

namespace VetroVivo.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly VetroVivoContext _context;

    public AuthController(VetroVivoContext context)
    {
        _context = context;
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginDto login)
    {
        var user = await _context.Customers
            .FirstOrDefaultAsync(u => u.Email == login.Email && u.IsActive);

        if (user == null)
            return Unauthorized(new { message = "E-mail ou senha inválidos." });

        // Nota: Aqui você deve implementar a verificação usando o Salt do seu banco
        // Por agora, faremos uma comparação simples para teste
        if (user.PasswordHash != login.Password)
            return Unauthorized(new { message = "E-mail ou senha inválidos." });

        return Ok(new
        {
            message = "Login realizado com sucesso!",
            userId = user.CustomerId,
            email = user.Email
        });
    }
}

public record LoginDto(string Email, string Password);