using ContactRequests.Domain;
using Microsoft.EntityFrameworkCore;

namespace ContactRequests.Infrastructure.Persistence;

public sealed class ContactRequestsDbContext(DbContextOptions<ContactRequestsDbContext> options)
    : DbContext(options)
{
    public DbSet<ContactRequest> ContactRequests => Set<ContactRequest>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(ContactRequestsDbContext).Assembly);
    }
}
