using ContactRequests.Domain;

namespace ContactRequests.Test.Domain;

public sealed class ContactRequestTests
{
    [Fact]
    public void Create_AssignsPendingStatus_AndGeneratedId()
    {
        var contactRequest = ContactRequest.Create("Alice", "alice@example.com", "Message with enough size");

        Assert.NotEqual(Guid.Empty, contactRequest.Id);
        Assert.Equal(ContactRequestStatus.Pending, contactRequest.Status);
    }
}
