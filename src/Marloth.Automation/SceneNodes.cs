using Godot;

namespace Marloth.Automation;

/// <summary>Small scene-tree lookup helpers for in-process automation.</summary>
public static class SceneNodes
{
    /// <summary>
    /// Returns the current scene if it is <typeparamref name="T"/>, otherwise a direct child named
    /// <paramref name="childName"/> of that type.
    /// </summary>
    public static T? FindInCurrentScene<T>(SceneTree tree, string childName)
        where T : class
    {
        ArgumentNullException.ThrowIfNull(tree);
        var scene = tree.CurrentScene;
        if (scene is null)
            return null;
        if (scene is T match)
            return match;
        if (scene.GetNodeOrNull(childName) is T child)
            return child;
        return null;
    }
}
