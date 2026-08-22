namespace Marloth.Functional.Tests;

/// <summary>
/// Tolerance helpers for functional asserts. Put the band next to the documented requirement
/// (see testing.md). Shared helpers stay under tests/, not product assemblies.
/// </summary>
public static class WithinRange
{
    public static bool Scalar(double actual, double expected, double absoluteTolerance) =>
        Math.Abs(actual - expected) <= absoluteTolerance;
}
