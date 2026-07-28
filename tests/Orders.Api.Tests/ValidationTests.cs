using Orders.Api;

namespace Orders.Api.Tests;

[TestClass]
public sealed class ValidationTests
{
    [TestMethod]
    [TestCategory("Validation")]
    [TestCategory("US3")]
    public void Validate_accumulates_absent_null_whitespace_item_and_quantity_errors()
    {
        var absent = OrderValidator.Validate(new CreateOrderRequest(null, null));
        AssertErrorKeys(absent, "customerId", "items");
        var empty = OrderValidator.Validate(
            new CreateOrderRequest("customer", Array.Empty<CreateOrderItemRequest?>()));
        AssertErrorKeys(empty, "items");

        var combined = OrderValidator.Validate(
            new CreateOrderRequest(
                "   ",
                [
                    null,
                    new CreateOrderItemRequest(null, null),
                    new CreateOrderItemRequest("\t", 0),
                    new CreateOrderItemRequest("negative", -1)
                ]));

        AssertErrorKeys(
            combined,
            "customerId",
            "items[0]",
            "items[1].productId",
            "items[1].quantity",
            "items[2].productId",
            "items[2].quantity",
            "items[3].quantity");
        Assert.IsFalse(combined.IsValid);
    }

    [TestMethod]
    [TestCategory("Validation")]
    [TestCategory("US3")]
    public void Validate_treats_ordinally_distinct_identifiers_as_distinct()
    {
        var result = OrderValidator.Validate(
            new CreateOrderRequest(
                "customer",
                [
                    new CreateOrderItemRequest("Product", 1),
                    new CreateOrderItemRequest("product", 1),
                    new CreateOrderItemRequest(" product", 1),
                    new CreateOrderItemRequest("\u00e9", 1),
                    new CreateOrderItemRequest("e\u0301", 1)
                ]));

        Assert.IsTrue(result.IsValid);
        Assert.AreEqual(0, result.Errors.Count);
        Assert.AreEqual(5, result.Value!.Items.Count);
    }

    [TestMethod]
    [TestCategory("Validation")]
    [TestCategory("US3")]
    public void Validate_reports_each_later_duplicate_by_index_without_echoing_input()
    {
        const string firstCanary = "duplicate-canary-first";
        const string secondCanary = "duplicate-canary-second";
        var result = OrderValidator.Validate(
            new CreateOrderRequest(
                "customer",
                [
                    new CreateOrderItemRequest(firstCanary, 1),
                    new CreateOrderItemRequest(firstCanary, 2),
                    new CreateOrderItemRequest(firstCanary, 3),
                    new CreateOrderItemRequest(secondCanary, 4),
                    new CreateOrderItemRequest(secondCanary, 5)
                ]));

        AssertErrorKeys(
            result,
            "items[1].productId",
            "items[2].productId",
            "items[4].productId");
        Assert.AreEqual(
            "Duplica el identificador del elemento en el índice 0.",
            result.Errors["items[1].productId"].Single());
        Assert.AreEqual(
            "Duplica el identificador del elemento en el índice 0.",
            result.Errors["items[2].productId"].Single());
        Assert.AreEqual(
            "Duplica el identificador del elemento en el índice 3.",
            result.Errors["items[4].productId"].Single());
        var allMessages = string.Join(" ", result.Errors.SelectMany(pair => pair.Value));
        Assert.IsFalse(allMessages.Contains(firstCanary, StringComparison.Ordinal));
        Assert.IsFalse(allMessages.Contains(secondCanary, StringComparison.Ordinal));
    }

    private static void AssertErrorKeys(
        OrderValidationResult result,
        params string[] expected)
    {
        Assert.IsFalse(result.IsValid);
        CollectionAssert.AreEquivalent(expected, result.Errors.Keys.ToArray());
        Assert.IsTrue(result.Errors.Values.All(messages => messages.Length > 0));
    }
}
