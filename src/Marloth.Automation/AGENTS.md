# Agent notes — Marloth.Automation

## Purpose

Standalone in-process Godot automation helpers (process/physics frame wait, input push, scene lookup) used by playbooks inside the live Godot process.

## What may live here

- GodotSharp-only helpers shared by playbook libraries

## What must not live here

- References to **Marloth.Automation.Contracts**, playbook interfaces, or test projects
- Game Core rules or Client composition
- gRPC server hosting (Client’s `GodotRpcHost` owns that)

Package dependency: **GodotSharp** only. See [testing.md](../../docs/technical/features/platform/testing.md).
