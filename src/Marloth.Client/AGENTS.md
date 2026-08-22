# Agent notes — Marloth.Client

## Purpose

Godot-facing presentation and local play: rendering, device input, scene roots. Also a class library for tests. Sources under this tree are compiled into the Godot host assembly as well.

## What may live here

- Godot nodes/scripts for world visuals and scene roots
- Automation RPC host (`GodotRpcHost`) implementing contracts from **Marloth.Automation.Contracts** (see [testing.md](../../docs/technical/features/platform/testing.md))

## What must not live here

- Authoritative game rules or world mutation owned by Core
- Playbook implementations (those live under `tests/`)

## I/O

Light device/engine I/O is expected (keyboard/joypad, display, scene tree).

Depends on Core as gameplay grows; also Automation + Automation.Contracts for the RPC surface.
