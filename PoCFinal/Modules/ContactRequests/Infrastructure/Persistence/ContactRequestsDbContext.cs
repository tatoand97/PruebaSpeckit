using ContactRequests.Infrastructure.Persistence.Configurations;
using Microsoft.EntityFrameworkCore;

namespace ContactRequests.Infrastructure.Persistence;

public sealed class ContactRequestsDbContext(DbContextOptions<ContactRequestsDbContext> options)
    : DbContext(options)
{
    public DbSet<ContactRequestEntity> ContactRequests => Set<ContactRequestEntity>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfiguration(new ContactRequestEntityConfiguration());
        base.OnModelCreating(modelBuilder);
    }
}
