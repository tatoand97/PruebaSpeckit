using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Orders.Domain;

namespace Orders.Infrastructure.Persistence;

public sealed class OrderConfiguration : IEntityTypeConfiguration<Order>
{
    public void Configure(EntityTypeBuilder<Order> builder)
    {
        builder.ToTable("Orders");
        builder.HasKey(order => order.Id);
        builder.Property(order => order.CustomerId).IsRequired();
        builder.Property(order => order.CreatedAt).IsRequired();

        builder.OwnsMany(
            order => order.Items,
            items =>
            {
                items.ToTable("OrderItems");
                items.WithOwner().HasForeignKey("OrderId");
                items.Property<int>("LineNumber").ValueGeneratedOnAdd();
                items.HasKey("OrderId", "LineNumber");
                items.Property(item => item.ProductId).IsRequired();
                items.Property(item => item.Quantity).IsRequired();
            });

        builder.Navigation(order => order.Items)
            .UsePropertyAccessMode(PropertyAccessMode.Field);
    }
}
