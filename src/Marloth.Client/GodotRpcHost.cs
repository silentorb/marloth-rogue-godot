using System.Collections.Concurrent;
using Godot;
using Grpc.Core;
using Marloth.Automation;
using Marloth.Automation.Contracts;

namespace Marloth.Client;

/// <summary>
/// Runtime autoload that exposes gRPC automation endpoints for external xUnit tests,
/// including loading and running playbook libraries after process start.
/// </summary>
public partial class GodotRpcHost : Node
{
    private const string DefaultScenePath = "res://main.tscn";
    private readonly ConcurrentQueue<Func<Task>> _mainThreadQueue = new();
    private readonly PlaybookRegistry _playbooks = new();
    private Server? _server;
    private bool _isEnabled;

    public override void _Ready()
    {
        _isEnabled = ReadEnabledFlag();
        if (!_isEnabled)
            return;

        var host = System.Environment.GetEnvironmentVariable("MARLOTH_AUTOMATION_HOST");
        if (string.IsNullOrWhiteSpace(host))
            host = "127.0.0.1";

        var port = 50061;
        var rawPort = System.Environment.GetEnvironmentVariable("MARLOTH_AUTOMATION_PORT");
        if (!string.IsNullOrWhiteSpace(rawPort) && int.TryParse(rawPort, out var parsed))
            port = parsed;

        _server = new Server
        {
            Services = { AutomationService.BindService(new AutomationServiceImpl(this)) },
            Ports = { new ServerPort(host, port, ServerCredentials.Insecure) },
        };
        _server.Start();
        GD.Print($"GodotRpcHost listening on {host}:{port}");
    }

    public override async void _ExitTree()
    {
        if (_server is null)
            return;
        await _server.ShutdownAsync();
        _server = null;
    }

    public override void _Process(double delta)
    {
        if (!_isEnabled)
            return;

        while (_mainThreadQueue.TryDequeue(out var action))
            _ = action();
    }

    private static bool ReadEnabledFlag()
    {
        var value = System.Environment.GetEnvironmentVariable("MARLOTH_AUTOMATION_ENABLED");
        if (string.IsNullOrWhiteSpace(value))
            return false;

        return string.Equals(value, "1", StringComparison.OrdinalIgnoreCase)
            || string.Equals(value, "true", StringComparison.OrdinalIgnoreCase)
            || string.Equals(value, "yes", StringComparison.OrdinalIgnoreCase);
    }

    private Task<T> RunOnMainThread<T>(Func<Task<T>> action)
    {
        var tcs = new TaskCompletionSource<T>(TaskCreationOptions.RunContinuationsAsynchronously);
        _mainThreadQueue.Enqueue(async () =>
        {
            try
            {
                var value = await action();
                tcs.TrySetResult(value);
            }
            catch (Exception ex)
            {
                tcs.TrySetException(ex);
            }
        });
        return tcs.Task;
    }

    private Task RunOnMainThread(Func<Task> action)
    {
        var tcs = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        _mainThreadQueue.Enqueue(async () =>
        {
            try
            {
                await action();
                tcs.TrySetResult();
            }
            catch (Exception ex)
            {
                tcs.TrySetException(ex);
            }
        });
        return tcs.Task;
    }

    private async Task WaitFramesAsync(int frameCount)
    {
        await SceneFrames.WaitAsync(GetTree(), frameCount);
    }

    private async Task WaitPhysicsFramesAsync(int frameCount)
    {
        await PhysicsFrames.WaitAsync(GetTree(), frameCount);
    }

    private sealed class PlaybookContext(GodotRpcHost owner) : IPlaybookContext
    {
        public Task LoadSceneAsync(string? scenePath, CancellationToken cancellationToken = default) =>
            owner.RunOnMainThread(async () =>
            {
                cancellationToken.ThrowIfCancellationRequested();
                var path = string.IsNullOrWhiteSpace(scenePath) ? DefaultScenePath : scenePath;
                var error = owner.GetTree().ChangeSceneToFile(path);
                if (error != Error.Ok)
                    throw new InvalidOperationException($"ChangeSceneToFile failed with {error}.");
                await owner.WaitFramesAsync(2);
            });

        public Task WaitFramesAsync(int frameCount, CancellationToken cancellationToken = default) =>
            owner.RunOnMainThread(async () =>
            {
                cancellationToken.ThrowIfCancellationRequested();
                await owner.WaitFramesAsync(frameCount);
            });

        public Task WaitPhysicsFramesAsync(int frameCount, CancellationToken cancellationToken = default) =>
            owner.RunOnMainThread(async () =>
            {
                cancellationToken.ThrowIfCancellationRequested();
                await owner.WaitPhysicsFramesAsync(frameCount);
            });

        public Task SetKeyStateAsync(int keyCode, bool pressed, CancellationToken cancellationToken = default) =>
            owner.RunOnMainThread(() =>
            {
                cancellationToken.ThrowIfCancellationRequested();
                InputPush.SetKey(owner, (Key)keyCode, pressed);
                return Task.CompletedTask;
            });

        public Task SetJoypadButtonAsync(
            int deviceIndex,
            int joyButton,
            bool pressed,
            CancellationToken cancellationToken = default) =>
            owner.RunOnMainThread(() =>
            {
                cancellationToken.ThrowIfCancellationRequested();
                InputPush.SetJoypadButton(owner, deviceIndex, (JoyButton)joyButton, pressed);
                return Task.CompletedTask;
            });

        public Task<PlaybookSceneSnapshot> GetSceneSnapshotAsync(CancellationToken cancellationToken = default) =>
            owner.RunOnMainThread(async () =>
            {
                cancellationToken.ThrowIfCancellationRequested();
                await owner.WaitFramesAsync(1);
                var scene = owner.GetTree().CurrentScene;
                return new PlaybookSceneSnapshot
                {
                    SceneLoaded = scene is not null,
                    ScenePath = scene?.SceneFilePath ?? "",
                    RootName = scene?.Name ?? "",
                    RootChildCount = scene?.GetChildCount() ?? 0,
                };
            });

        public Task<PlaybookControlRectSnapshot> GetControlRectAsync(
            string nodePath,
            CancellationToken cancellationToken = default) =>
            owner.RunOnMainThread(async () =>
            {
                cancellationToken.ThrowIfCancellationRequested();
                await owner.WaitFramesAsync(1);
                var scene = owner.GetTree().CurrentScene;
                if (scene is null || string.IsNullOrWhiteSpace(nodePath))
                    return new PlaybookControlRectSnapshot { Found = false };

                if (scene.GetNodeOrNull(nodePath) is not Control control)
                    return new PlaybookControlRectSnapshot { Found = false };

                var rect = control.GetGlobalRect();
                var min = control.GetCombinedMinimumSize();
                return new PlaybookControlRectSnapshot
                {
                    Found = true,
                    Visible = control.Visible && control.IsVisibleInTree(),
                    X = rect.Position.X,
                    Y = rect.Position.Y,
                    Width = rect.Size.X,
                    Height = rect.Size.Y,
                    MinWidth = min.X,
                    MinHeight = min.Y,
                    ClassName = control.GetClass(),
                };
            });

        public Task<string?> GetLabelTextAsync(
            string nodePath,
            CancellationToken cancellationToken = default) =>
            owner.RunOnMainThread(async () =>
            {
                cancellationToken.ThrowIfCancellationRequested();
                await owner.WaitFramesAsync(1);
                var scene = owner.GetTree().CurrentScene;
                if (scene is null || string.IsNullOrWhiteSpace(nodePath))
                    return null;
                return scene.GetNodeOrNull<Label>(nodePath)?.Text;
            });

        public Task PressButtonAsync(
            string nodePath,
            CancellationToken cancellationToken = default) =>
            owner.RunOnMainThread(() =>
            {
                cancellationToken.ThrowIfCancellationRequested();
                var scene = owner.GetTree().CurrentScene
                    ?? throw new InvalidOperationException("No current scene.");
                var button = scene.GetNodeOrNull<Button>(nodePath)
                    ?? throw new InvalidOperationException($"Button missing: {nodePath}");
                button.EmitSignal(BaseButton.SignalName.Pressed);
                return Task.CompletedTask;
            });

        public Task<PlaybookControlRectSnapshot> GetViewportVisibleRectAsync(
            CancellationToken cancellationToken = default) =>
            owner.RunOnMainThread(async () =>
            {
                cancellationToken.ThrowIfCancellationRequested();
                await owner.WaitFramesAsync(1);
                var rect = owner.GetViewport().GetVisibleRect();
                return new PlaybookControlRectSnapshot
                {
                    Found = true,
                    Visible = true,
                    X = rect.Position.X,
                    Y = rect.Position.Y,
                    Width = rect.Size.X,
                    Height = rect.Size.Y,
                };
            });

        public Task SetWindowSizeAsync(int width, int height, CancellationToken cancellationToken = default) =>
            owner.RunOnMainThread(async () =>
            {
                cancellationToken.ThrowIfCancellationRequested();
                if (width < 1 || height < 1)
                    throw new ArgumentOutOfRangeException(nameof(width), "Window size must be positive.");
                var size = new Vector2I(width, height);
                DisplayServer.WindowSetSize(size);
                var window = owner.GetWindow();
                if (window is not null)
                    window.Size = size;
                owner.GetTree().Root.Size = size;
                await owner.WaitFramesAsync(2);
            });
    }

    private sealed class AutomationServiceImpl(GodotRpcHost owner) : AutomationService.AutomationServiceBase
    {
        private readonly PlaybookContext _playbookContext = new(owner);

        public override Task<PingResponse> Ping(PingRequest request, ServerCallContext context)
        {
            return Task.FromResult(new PingResponse { Ok = true, Message = "pong" });
        }

        public override Task<LoadPlaybookLibraryResponse> LoadPlaybookLibrary(
            LoadPlaybookLibraryRequest request,
            ServerCallContext context)
        {
            var outcome = owner._playbooks.LoadLibrary(request.AssemblyPath);
            var response = new LoadPlaybookLibraryResponse
            {
                Ok = outcome.Success,
                Error = outcome.Error,
            };
            response.PlaybookIds.AddRange(outcome.PlaybookIds);
            return Task.FromResult(response);
        }

        public override Task<ListPlaybooksResponse> ListPlaybooks(
            ListPlaybooksRequest request,
            ServerCallContext context)
        {
            var response = new ListPlaybooksResponse { Ok = true };
            response.PlaybookIds.AddRange(owner._playbooks.ListIds());
            return Task.FromResult(response);
        }

        public override async Task<PlaybookResultResponse> RunPlaybook(
            RunPlaybookRequest request,
            ServerCallContext context)
        {
            if (string.IsNullOrWhiteSpace(request.PlaybookId))
            {
                return new PlaybookResultResponse
                {
                    Ok = false,
                    Error = "playbook_id is required.",
                };
            }

            if (!owner._playbooks.TryGet(request.PlaybookId, out var playbook) || playbook is null)
            {
                return new PlaybookResultResponse
                {
                    Ok = false,
                    Error = $"Unknown playbook id '{request.PlaybookId}'.",
                };
            }

            try
            {
                var result = await playbook.RunAsync(
                    _playbookContext,
                    request.ArgsJson ?? "",
                    context.CancellationToken);
                return new PlaybookResultResponse
                {
                    Ok = result.Ok,
                    Error = result.Error,
                    Diagnostics = result.Diagnostics,
                };
            }
            catch (Exception ex)
            {
                return new PlaybookResultResponse
                {
                    Ok = false,
                    Error = ex.Message,
                };
            }
        }

        public override async Task<CommandResponse> Shutdown(ShutdownRequest request, ServerCallContext context)
        {
            try
            {
                await owner.RunOnMainThread(() =>
                {
                    owner.GetTree().Quit();
                    return Task.CompletedTask;
                });
                return new CommandResponse { Ok = true };
            }
            catch (Exception ex)
            {
                return new CommandResponse { Ok = false, Error = ex.Message };
            }
        }
    }
}
