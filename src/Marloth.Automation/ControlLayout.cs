using Godot;

namespace Marloth.Automation;

/// <summary>Control rect helpers for in-process layout assertions.</summary>
public static class ControlLayout
{
    /// <summary>
    /// Returns true when <paramref name="inner"/> lies fully inside <paramref name="outer"/>,
    /// allowing <paramref name="epsilon"/> pixels of floating-point / rounding slack on each edge.
    /// </summary>
    public static bool Contains(Rect2 outer, Rect2 inner, float epsilon = 1f)
    {
        return inner.Position.X >= outer.Position.X - epsilon
            && inner.Position.Y >= outer.Position.Y - epsilon
            && inner.End.X <= outer.End.X + epsilon
            && inner.End.Y <= outer.End.Y + epsilon;
    }
}
