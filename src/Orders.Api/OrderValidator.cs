namespace Orders.Api;

internal sealed record ValidatedCreateOrder(
    string CustomerId,
    IReadOnlyList<OrderItem> Items);

internal sealed record OrderValidationResult(
    ValidatedCreateOrder? Value,
    IReadOnlyDictionary<string, string[]> Errors)
{
    internal bool IsValid => Value is not null;
}

internal static class OrderValidator
{
    internal static OrderValidationResult Validate(CreateOrderRequest request)
    {
        ArgumentNullException.ThrowIfNull(request);

        var errors = new Dictionary<string, List<string>>(StringComparer.Ordinal);
        if (string.IsNullOrWhiteSpace(request.CustomerId))
        {
            AddError(errors, "customerId", "Debe contener al menos un carácter distinto de espacio.");
        }

        var validatedItems = new List<OrderItem>();
        var firstProductIndexes = new Dictionary<string, int>(StringComparer.Ordinal);
        if (request.Items is null || request.Items.Count == 0)
        {
            AddError(errors, "items", "Debe contener al menos un producto.");
        }
        else
        {
            for (var index = 0; index < request.Items.Count; index++)
            {
                var item = request.Items[index];
                if (item is null)
                {
                    AddError(errors, $"items[{index}]", "El elemento no puede ser nulo.");
                    continue;
                }

                var productUsable = !string.IsNullOrWhiteSpace(item.ProductId);
                if (!productUsable)
                {
                    AddError(
                        errors,
                        $"items[{index}].productId",
                        "Debe contener al menos un carácter distinto de espacio.");
                }
                else if (firstProductIndexes.TryGetValue(item.ProductId!, out var firstIndex))
                {
                    AddError(
                        errors,
                        $"items[{index}].productId",
                        $"Duplica el identificador del elemento en el índice {firstIndex}.");
                }
                else
                {
                    firstProductIndexes.Add(item.ProductId!, index);
                }

                var quantityUsable = item.Quantity is > 0;
                if (!quantityUsable)
                {
                    AddError(
                        errors,
                        $"items[{index}].quantity",
                        "Debe ser un entero mayor que cero.");
                }

                if (productUsable && quantityUsable)
                {
                    validatedItems.Add(new OrderItem(item.ProductId!, item.Quantity!.Value));
                }
            }
        }

        if (errors.Count != 0)
        {
            return new OrderValidationResult(
                null,
                errors.ToDictionary(
                    pair => pair.Key,
                    pair => pair.Value.ToArray(),
                    StringComparer.Ordinal));
        }

        return new OrderValidationResult(
            new ValidatedCreateOrder(request.CustomerId!, validatedItems.ToArray()),
            new Dictionary<string, string[]>(StringComparer.Ordinal));
    }

    private static void AddError(
        IDictionary<string, List<string>> errors,
        string key,
        string message)
    {
        if (!errors.TryGetValue(key, out var messages))
        {
            messages = [];
            errors.Add(key, messages);
        }

        messages.Add(message);
    }
}

