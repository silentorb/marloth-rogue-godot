using System.Threading;
using System.Threading.Tasks;

namespace Marloth.Automation.Contracts;

/// <summary>Named automation routine discovered inside a playbook library.</summary>
public interface IPlaybook
{
    /// <summary>Stable short name within the library (qualified as AssemblyName.Id in the registry).</summary>
    string Id { get; }

    Task<PlaybookResult> RunAsync(IPlaybookContext context, string argsJson, CancellationToken cancellationToken);
}

/// <summary>Thin host facade for playbooks running on the Godot main thread.</summary>
public interface IPlaybookContext
{
    Task LoadSceneAsync(string? scenePath, CancellationToken cancellationToken = default);

    Task WaitFramesAsync(int frameCount, CancellationToken cancellationToken = default);

    Task WaitPhysicsFramesAsync(int frameCount, CancellationToken cancellationToken = default);

    Task SetKeyStateAsync(int keyCode, bool pressed, CancellationToken cancellationToken = default);

    Task SetJoypadButtonAsync(int deviceIndex, int joyButton, bool pressed, CancellationToken cancellationToken = default);

    Task<PlaybookSceneSnapshot> GetSceneSnapshotAsync(CancellationToken cancellationToken = default);

    /// <summary>
    /// Global rect of a <c>Control</c> at <paramref name="nodePath"/> under the current scene
    /// (Godot node path, e.g. <c>Margin/Panel</c>).
    /// </summary>
    Task<PlaybookControlRectSnapshot> GetControlRectAsync(
        string nodePath,
        CancellationToken cancellationToken = default);

    /// <summary>Visible rect of the root viewport in global coordinates.</summary>
    Task<PlaybookControlRectSnapshot> GetViewportVisibleRectAsync(
        CancellationToken cancellationToken = default);

    /// <summary>Resize the main window (forces a layout pass after the next frames).</summary>
    Task SetWindowSizeAsync(int width, int height, CancellationToken cancellationToken = default);

    /// <summary>Text of a Label at <paramref name="nodePath"/>, or null.</summary>
    Task<string?> GetLabelTextAsync(string nodePath, CancellationToken cancellationToken = default);

    /// <summary>Emit <c>Pressed</c> on a Button at <paramref name="nodePath"/> under the current scene.</summary>
    Task PressButtonAsync(string nodePath, CancellationToken cancellationToken = default);
}

/// <summary>Outcome of a playbook run (also mirrored on the gRPC wire).</summary>
public sealed class PlaybookResult
{
    public bool Ok { get; init; }
    public string Error { get; init; } = "";
    public string Diagnostics { get; init; } = "";

    public static PlaybookResult Success(string diagnostics = "") =>
        new() { Ok = true, Diagnostics = diagnostics ?? "" };

    public static PlaybookResult Fail(string error, string diagnostics = "") =>
        new() { Ok = false, Error = error ?? "", Diagnostics = diagnostics ?? "" };
}

/// <summary>Minimal current-scene snapshot for playbook assertions.</summary>
public sealed class PlaybookSceneSnapshot
{
    public bool SceneLoaded { get; init; }
    public string ScenePath { get; init; } = "";
    public string RootName { get; init; } = "";
    public int RootChildCount { get; init; }
}

/// <summary>Control or viewport rect for layout assertions (global coordinates).</summary>
public sealed class PlaybookControlRectSnapshot
{
    public bool Found { get; init; }
    public bool Visible { get; init; }
    public float X { get; init; }
    public float Y { get; init; }
    public float Width { get; init; }
    public float Height { get; init; }
    public float MinWidth { get; init; }
    public float MinHeight { get; init; }
    /// <summary>Godot class name (e.g. ScrollContainer), empty when not found.</summary>
    public string ClassName { get; init; } = "";
}
