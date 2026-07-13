# Project Guidelines

## Architecture

- Use MVVM.
- Keep business logic in ViewModels and domain services.
- Views must remain passive and presentation-focused.
- Do not introduce new architectural patterns.

## SwiftUI

- Keep views small and composable.
- Extract reusable components only when reused or clearly improving readability.
- Avoid business logic inside SwiftUI views.

## Dependencies

- Use existing project dependencies only.
- Do not add third-party libraries.

## Networking

- Keep networking inside service layer.
- Do not perform networking directly from views.

## Code Changes

- Make the smallest change that solves the task.
- Do not refactor unrelated code.
- Do not rename symbols unless required.

## Verification

- Build the app after changes.
- Run relevant tests.
- Never claim tests pass unless they were executed.

## UI

- Do not introduce visual changes unless requested.
- Reuse CurrencyConverterStyle when possible.

## Localization

- Do not add localization unless explicitly requested.

## Git

- Never commit, push, rebase, reset or modify git history unless explicitly requested.