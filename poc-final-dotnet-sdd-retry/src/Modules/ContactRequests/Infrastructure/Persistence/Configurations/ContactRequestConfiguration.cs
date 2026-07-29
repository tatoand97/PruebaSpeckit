using ContactRequests.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace ContactRequests.Infrastructure.Persistence.Configurations;

public sealed class ContactRequestConfiguration : IEntityTypeConfiguration<ContactRequest>
{
    public void Configure(EntityTypeBuilder<ContactRequest> builder)
    {
        builder.ToTable("ContactRequests");
        builder.HasKey(contactRequest => contactRequest.Id);

        builder.Property(contactRequest => contactRequest.Id)
            .HasColumnType("uniqueidentifier")
            .ValueGeneratedNever();

        builder.Property(contactRequest => contactRequest.Name)
            .HasColumnType("nvarchar(300)")
            .IsRequired();

        builder.Property(contactRequest => contactRequest.Email)
            .HasColumnType("nvarchar(320)")
            .IsRequired();

        builder.Property(contactRequest => contactRequest.Subject)
            .HasColumnType("nvarchar(400)")
            .IsRequired();

        builder.Property(contactRequest => contactRequest.Message)
            .HasColumnType("nvarchar(4000)")
            .IsRequired();

        builder.Property(contactRequest => contactRequest.CreatedAtUtc)
            .HasColumnType("datetimeoffset")
            .IsRequired();
    }
}
