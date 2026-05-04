using Microsoft.EntityFrameworkCore;
using VetroVivo.Models;

namespace VetroVivo.Data;

public class VetroVivoContext : DbContext
{
    public VetroVivoContext(DbContextOptions<VetroVivoContext> options) : base(options) { }

    public DbSet<Customer> Customers { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.HasPostgresExtension("uuid-ossp");

        // Mapeamento explícito para o schema 'core'
        modelBuilder.Entity<Customer>().ToTable("customers", "core");

        base.OnModelCreating(modelBuilder);
    }
}