using Marloth.Automation.Contracts;

namespace Marloth.Functional.Godot.Playbooks;

/// <summary>Loads the main scene and asserts the documented root node is present.</summary>
public sealed class MainSceneBootstrapPlaybook : IPlaybook
{
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

        return PlaybookResult.Success(Diagnostics(snap));
    }

    private static string Diagnostics(PlaybookSceneSnapshot snap) =>
        $"path={snap.ScenePath};root={snap.RootName};children={snap.RootChildCount}";
}
