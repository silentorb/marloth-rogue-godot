# Agent notes — Marloth.Automation.Contracts

## Purpose

Protobuf/gRPC wire protocol and playbook interfaces for Godot functional automation.

## What may live here

- Generated and hand-written contract types for the automation RPC surface
- `IPlaybook`, `IPlaybookContext`, `PlaybookResult`, and related interfaces

## What must not live here

- In-process Godot helpers (those live in **Marloth.Automation**)
- Playbook implementations or xUnit test projects (under `tests/`)
- Game Core or Client presentation logic

See [testing.md](../../docs/technical/features/platform/testing.md).
