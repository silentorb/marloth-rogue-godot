using Marloth.Automation.Contracts;
using Xunit;

namespace Marloth.Functional.Godot.Tests;

[Collection("GodotAutomation")]
public sealed class MainSceneFunctionalTest(GodotAutomationFixture fixture)
{
    [Fact]
    public async Task Main_scene_bootstraps_root_node()
    {
        var result = await fixture.Client.RunPlaybookAsync(new RunPlaybookRequest
        {
            PlaybookId = GodotAutomationFixture.MainSceneBootstrapId,
        });
        Assert.True(result.Ok, $"Playbook failed: {result.Error} {result.Diagnostics}");
    }
}
