using Godot;

namespace Marloth.Automation;

/// <summary>Viewport input injection for playbooks.</summary>
public static class InputPush
{
    public static void SetKey(Node treeRoot, Key key, bool pressed)
    {
        var ev = new InputEventKey
        {
            Keycode = key,
            PhysicalKeycode = key,
            Pressed = pressed,
        };
        treeRoot.GetTree()?.Root?.PushInput(ev);
    }

    public static void SetJoypadButton(Node treeRoot, int deviceIndex, JoyButton button, bool pressed)
    {
        var ev = new InputEventJoypadButton
        {
            Device = deviceIndex,
            ButtonIndex = button,
            Pressed = pressed,
        };
        treeRoot.GetTree()?.Root?.PushInput(ev);
    }
}
