using System.ComponentModel.DataAnnotations.Schema;

namespace VetroVivo.Models;

[Table("customers", Schema = "core")]
public class Customer
{
    public Guid CustomerId { get; set; }
    public Guid StoreId { get; set; }
    public string Email { get; set; } = null!;

    [Column("password_hash")]
    public string PasswordHash { get; set; } = null!;

    public string Salt { get; set; } = null!;

    [Column("is_active")]
    public bool IsActive { get; set; } = true;
}