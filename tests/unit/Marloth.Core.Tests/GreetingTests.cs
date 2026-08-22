using Marloth.Core;
using Xunit;

namespace Marloth.Core.Tests;

public class GreetingTests
{
    [Fact]
    public void Hello_returns_expected_token()
    {
        Assert.Equal("marloth", Greeting.Hello());
    }
}
