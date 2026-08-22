using Xunit;

namespace Marloth.Functional.Tests;

public class WithinRangeTests
{
    [Fact]
    public void Scalar_accepts_value_inside_absolute_tolerance()
    {
        Assert.True(WithinRange.Scalar(1.02, 1.0, 0.05));
        Assert.False(WithinRange.Scalar(1.2, 1.0, 0.05));
    }
}
