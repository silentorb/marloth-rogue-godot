using Marloth.Automation.Contracts;

namespace Marloth.Functional.Godot.Playbooks;

/// <summary>
/// Loads the main scene and asserts the documented root plus instanced margen debug world.
/// </summary>
public sealed class MainSceneBootstrapPlaybook : IPlaybook
{
    public const string MargenWorldDebugChild = "MargenWorldDebug";

    /// <summary>
    /// Mesh under the instanced debug world — presence proves the child tree loaded
    /// (vertex band stays in <see cref="MargenWorldDebugPlaybook"/>).
    /// </summary>
    public const string MargenWorldDebugMeshPath = "MargenWorldDebug/MargenWorldMesh/MeshInstance3D";

    public string Id => "MainSceneBootstrap";

    public async Task<PlaybookResult> RunAsync(
        IPlaybookContext context,
        string argsJson,
        CancellationToken cancellationToken)
    {
        await context.LoadSceneAsync("res://main.tscn", cancellationToken);
        await context.WaitFramesAsync(8, cancellationToken);

        var snap = await context.GetSceneSnapshotAsync(cancellationToken);
        if (!snap.SceneLoaded)
            return PlaybookResult.Fail("Scene was not loaded.");
        if (snap.RootName != "Root")
            return PlaybookResult.Fail($"Expected root name Root, got '{snap.RootName}'.", Diagnostics(snap));
        if (snap.RootChildCount < 1)
            return PlaybookResult.Fail($"Expected at least one child under Root (instanced {MargenWorldDebugChild}).", Diagnostics(snap));

        var mesh = await context.GetMeshInstanceSnapshotAsync(MargenWorldDebugMeshPath, cancellationToken);
        if (!mesh.Found)
        {
            return PlaybookResult.Fail(
                $"Expected instanced child path '{MargenWorldDebugMeshPath}' (main hosts {MargenWorldDebugChild}).",
                Diagnostics(snap, mesh));
        }

        return PlaybookResult.Success(Diagnostics(snap, mesh));
    }

    private static string Diagnostics(PlaybookSceneSnapshot snap, PlaybookMeshInstanceSnapshot? mesh = null)
    {
        var baseDiag = $"path={snap.ScenePath};root={snap.RootName};children={snap.RootChildCount}";
        if (mesh is null)
            return baseDiag;
        return $"{baseDiag};mesh_path={MargenWorldDebugMeshPath};mesh_found={mesh.Found}";
    }
}
