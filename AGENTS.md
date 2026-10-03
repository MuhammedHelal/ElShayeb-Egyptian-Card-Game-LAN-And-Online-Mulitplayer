# Repository Guidelines

## Project Structure & Module Organization

This is a Flutter/Dart card game with LAN and Supabase-backed online multiplayer.

### Key Patterns

- **State management**: Cubit/Bloc only. No Riverpod, Provider, or GetX. `setState` only for local UI state.
- **DI**: get_it (`sl`). Never instantiate cubits, use cases, or repos manually.
- **No Freezed/build_runner for state**: Use Dart 3+ `sealed class` for state unions with exhaustive `switch`.
- **Error handling**: Data layer catches exceptions -> returns `FailureOrSuccess<T>` (dartz `Either`). Use `executeAndHandleErrorsAsyncWrapper()` in repos to wrap calls.
- **Resource<T>**: Generic wrapper with `RequestState` (initial/loading/success/error) used in cubit states for trackable async operations.
- **Localization**: ARB files in `lib/l10n/` (intl_{lang}.arb). Generated code in `lib/generated/`. Access via `S.of(context)` or `S.current`.
- **Assets**: flutter_gen generates typed asset references to `lib/core/utils/assets/`.
- **Network**: Firebase (Firestore, Functions, Auth, Crashlytics, Messaging, Storage, RTDB) + Dio for REST APIs. Env keys loaded from `keys_{flavor}.env` via flutter_dotenv.

## AGENTS.md Rules

# Section A — General Engineering Rules

## 1) Architecture & Separation of Concerns (YOU MUST FOLLOW)
- Follow the project's architecture layer boundaries strictly: presentation → domain → data
- Never bypass layers or mix responsibilities
- UI/presentation layer has ZERO business logic — only rendering, interaction, and state observation
- Business logic lives in the domain layer
- Data access (APIs, databases, storage) lives in the data layer
- Do not introduce new abstractions or patterns without justification

## 2) Shared Code (IMPORTANT)
- Any reusable logic, utility, constant, extension, or helper used in 2+ places goes in `core/`
- Check `core/` before creating new shared code — never duplicate across features

## 3) Error Handling
- Errors flow cleanly across layers — never skip layers
- Handle null, empty, loading, and error states explicitly — no silent failures
- Catch errors at the boundary (data layer), not deep inside business logic

## 4) Workflow (Mandatory)
- Before new feature: invoke `/flutter-feature` skill
- Before marking done: run `/flutter-code-review` skill
- After task approved → use the `@git-expert` agent for branch, commit, and PR output

## 5) Agents — Proactively Suggest (YOU MUST FOLLOW)
You MUST proactively suggest the appropriate agent when the situation matches. Do not wait for the user to ask.

- `@debugger` — When a bug, crash, error, or unexpected behavior is encountered
- `@code-reviewer` — After `/flutter-code-review` passes, ALWAYS suggest running `@code-reviewer` for a deeper independent review before proceeding to PR
- `@git-expert` — When it's time to create a branch, commit, or PR. Also for merge conflicts, rebases, or any complex git situation

# Section B — Flutter / Dart Specific Rules

## 1) State Management
- Use **Cubit/Bloc** for feature and application state — not Riverpod, Provider, or GetX
- Cubits depend ONLY on use cases — never directly on repositories or data sources
- `setState` is allowed ONLY for local UI state (e.g., toggles, form focus) — never for business logic
- Keep `setState` scoped to the smallest widget possible to avoid redundant rebuilds up the tree

## 2) Build Method Discipline (IMPORTANT)
- Prefer `const` constructors wherever possible
- NEVER create `TextEditingController`, `AnimationController`, `FocusNode`, or other expensive objects inside `build()`
- Avoid heavy work inside `build()` methods
- Dispose controllers and focus nodes in `StatefulWidget.dispose()`
- Prefer small, composed widgets to minimize rebuild scope
- Use `BlocBuilder`/`BlocSelector` on the smallest widget that needs the state — never at the top of the tree