using Godot;

namespace Marloth.Automation;

/// <summary>Scene-tree process-frame stepping helpers for automation running inside Godot.</summary>
public static class SceneFrames
{
    /// <summary>Waits for at least one process frame (clamped).</summary>
    public static async Task WaitAsync(SceneTree tree, int frameCount = 1)
    {
        ArgumentNullException.ThrowIfNull(tree);
        var frames = Math.Max(1, frameCount);
        for (var i = 0; i < frames; i++)
            await tree.ToSignal(tree, SceneTree.SignalName.ProcessFrame);
    }
}
