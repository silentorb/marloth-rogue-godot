using System.Runtime.Loader;
using Marloth.Automation.Contracts;

namespace Marloth.Client;

/// <summary>Discovers and runs <see cref="IPlaybook"/> types from externally loaded assemblies.</summary>
internal sealed class PlaybookRegistry
{
    private readonly Dictionary<string, IPlaybook> _playbooks = new(StringComparer.Ordinal);
    private readonly Dictionary<string, List<string>> _idsByPath = new(StringComparer.OrdinalIgnoreCase);

    public IReadOnlyList<string> ListIds() => _playbooks.Keys.OrderBy(k => k, StringComparer.Ordinal).ToList();

    public LoadOutcome LoadLibrary(string assemblyPath)
    {
        if (string.IsNullOrWhiteSpace(assemblyPath))
            return LoadOutcome.Fail("assembly_path is required.");

        var fullPath = Path.GetFullPath(assemblyPath);
        if (!File.Exists(fullPath))
            return LoadOutcome.Fail($"Playbook library not found: {fullPath}");

        if (_idsByPath.TryGetValue(fullPath, out var already))
            return LoadOutcome.Ok(already);

        try
        {
            var hostAlc = AssemblyLoadContext.GetLoadContext(typeof(PlaybookRegistry).Assembly)
                ?? AssemblyLoadContext.Default;
            var assembly = hostAlc.LoadFromAssemblyPath(fullPath);
            var libraryName = assembly.GetName().Name ?? Path.GetFileNameWithoutExtension(fullPath);
            var discovered = new List<string>();

            foreach (var type in assembly.GetExportedTypes())
            {
                if (type.IsAbstract || type.IsInterface || !typeof(IPlaybook).IsAssignableFrom(type))
                    continue;

                IPlaybook playbook;
                try
                {
                    playbook = (IPlaybook)(Activator.CreateInstance(type)
                        ?? throw new InvalidOperationException($"Failed to construct {type.FullName}."));
                }
                catch (Exception ex)
                {
                    return LoadOutcome.Fail($"Failed to create playbook {type.FullName}: {ex.Message}");
                }

                if (string.IsNullOrWhiteSpace(playbook.Id))
                    return LoadOutcome.Fail($"Playbook type {type.FullName} has an empty Id.");

                var qualifiedId = $"{libraryName}.{playbook.Id}";
                if (!_playbooks.TryAdd(qualifiedId, playbook))
                    return LoadOutcome.Fail($"Duplicate playbook id '{qualifiedId}'.");

                discovered.Add(qualifiedId);
            }

            if (discovered.Count == 0)
                return LoadOutcome.Fail($"No IPlaybook types found in {fullPath}.");

            discovered.Sort(StringComparer.Ordinal);
            _idsByPath[fullPath] = discovered;
            return LoadOutcome.Ok(discovered);
        }
        catch (Exception ex)
        {
            return LoadOutcome.Fail(ex.Message);
        }
    }

    public bool TryGet(string playbookId, out IPlaybook? playbook) =>
        _playbooks.TryGetValue(playbookId, out playbook);

    internal readonly record struct LoadOutcome(bool Success, string Error, IReadOnlyList<string> PlaybookIds)
    {
        public static LoadOutcome Ok(IReadOnlyList<string> ids) => new(true, "", ids);
        public static LoadOutcome Fail(string error) => new(false, error, Array.Empty<string>());
    }
}
