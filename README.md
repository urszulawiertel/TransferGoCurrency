# TransferGo Currency Converter

## Overview

A SwiftUI currency converter built for the TransferGo iOS take-home assignment. It supports bidirectional conversion using current rates from the TransferGo FX API, searchable currency selection, per-currency sending limits, and swapping the selected currencies and amounts. The converter is delivered as a reusable local Swift package, with `TransferGoCurrencyApp` kept as a lightweight host application.

## Screenshots

| Demo | Converter | Currency Selection | Error State |
|------|-----------|-------------------|-------------|
| <img src="./Screenshots/demo.gif" alt="Demo recording" height="478" /> | <img src="./Screenshots/converter.png" alt="Converter screen" height="478" /> | <img src="./Screenshots/currency-selection.png" alt="Currency selection screen" height="478" /> | <img src="./Screenshots/error-state.png" alt="Error state screen" height="478" /> |

## Requirements

- macOS with Xcode and an iOS Simulator
- iOS 17.0 or later
- Internet access for live exchange rates
- No API key or other credentials—the endpoint is called without authentication

The local package declares Swift tools 5.9 and supports iOS 17 and macOS 14.

## Setup and running

```sh
git clone git@github.com:urszulawiertel/TransferGoCurrency.git
cd TransferGoCurrency
```

1. Open `TransferGoCurrencyApp.xcodeproj` in Xcode.
2. Select the `TransferGoCurrencyApp` scheme.
3. Choose an iOS 17 or newer Simulator.
4. Build and run with **Cmd + R**.

The command-line build used for verification is:

```sh
xcodebuild build \
  -project TransferGoCurrencyApp.xcodeproj \
  -scheme TransferGoCurrencyApp \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
```

## Running tests

### Swift Package tests

From the repository root:

```sh
cd CurrencyConverterFeature
swift test
```

This is the verified automated test flow and currently runs 69 XCTest cases.

### Xcode tests

Tests included in an active Xcode scheme can be run with **Cmd + U**. The shared `TransferGoCurrencyApp` scheme currently has no explicit test target in its test action, so the package command above is the reliable test path for this repository. No `xcodebuild test` command is documented because one is not configured for that scheme.

## Features

- Live currency conversion using TransferGo FX API
- Bidirectional conversion (send ↔ receive)
- Currency selection with search
- Currency swap
- Per-currency sending limits
- Network error handling
- Localization support
- Unit tested business logic

## Architecture

`TransferGoCurrencyApp` is the composition root: it imports the package and presents `CurrencyConverterView`. `CurrencyConverterFeature` contains the complete feature using MVVM:

- **Views** render state, bind editable values, and own transient presentation state such as which currency-selection sheet is open.
- **ViewModels** coordinate conversion, validation, loading and error state, request cancellation, swapping, and search filtering.
- **Domain models and validation** define currencies, rates, supported limits, and sending rules independently of SwiftUI.
- **Services** are injected through `FXRatesServicing`; the production implementation uses `URLSession` with async/await.
- **Formatting and localization** handle locale-aware display/editing, stable API serialization, and package-bundled localized strings.

Live rates are requested with `GET https://my.transfergo.com/api/fx-rates` using `from`, `to`, and `amount` query parameters.

```text
TransferGoCurrencyApp.xcodeproj/
TransferGoCurrencyApp/
└── TransferGoCurrencyApp.swift
CurrencyConverterFeature/
├── Package.swift
├── Sources/CurrencyConverterFeature/
│   ├── Data/
│   ├── Domain/
│   │   ├── Models/
│   │   └── Services/
│   ├── Presentation/
│   │   ├── Components/
│   │   ├── Formatting/
│   │   ├── Localization/
│   │   ├── Screens/
│   │   ├── Styling/
│   │   └── ViewModels/
│   ├── Resources/
│   └── Validation/
└── Tests/CurrencyConverterFeatureTests/
Screenshots/
```

### Supported currencies and limits

| Currency | Country | Maximum sending amount |
|----------|---------|------------------------|
| PLN | Poland | 20,000 PLN |
| EUR | Germany | 5,000 EUR |
| GBP | Great Britain | 1,000 GBP |
| UAH | Ukraine | 50,000 UAH |

## Key implementation decisions

- **`Decimal` for monetary values:** avoids binary floating-point rounding in amounts, limits, and decoded rates.
- **Locale-aware editing:** input uses the current locale's decimal separator and avoids grouping while editing. Fractional input is shown with validation but is not sent to the integer-only FX endpoint.
- **Stable API serialization:** request amounts use an `en_US_POSIX` representation, independent of the device locale.
- **Latest-request wins:** a new edit or currency change cancels the previous task, and request identifiers prevent stale responses from updating state.
- **Explicit state:** the converter ViewModel exposes loading, conversion-rate, and typed error state to keep Views presentation-focused.
- **View-owned presentation:** the converter View owns the active currency-selection sheet; conversion rules remain in the ViewModel.
- **Small package surface:** integration views, domain values, and the service protocol are public while implementation details remain internal.
- **System frameworks only:** SwiftUI, Foundation, Combine, and XCTest are used with no third-party dependencies.

## Error handling

- **Invalid amount:** invalid locale input is rejected by the editing formatter. Fractional values are retained for correction, show a whole-amount validation error, preserve the last successful conversion, and do not trigger an API request. Non-positive values do not trigger an API request or a sending-limit error.
- **Sending limit exceeded:** the ViewModel exposes the currency-specific limit error and skips a new forward request; the last successful conversion remains visible. Reverse conversions validate the resulting sending amount after the response.
- **Network or conversion failure:** offline and lost-connection errors show a dismissible network banner. Other service, response, or decoding failures show a generic inline conversion error.
- **Cancelled or stale request:** cancellation is ignored, and only the latest request may update displayed state.
- **Zero or empty input:** empty input becomes zero, clears the calculated counterpart and current error, and does not request a conversion. The current pair's displayed rate is retained; changing the pair at zero fetches a one-unit reference rate.

## Testing

The package contains 69 XCTest cases covering:

- supported currencies and sending limits
- FX URL construction, locale-independent amount serialization, response decoding, and transport errors
- initial, forward, and reverse ViewModel conversion behavior
- currency changes, swapping, loading, and latest-request handling
- request cancellation and stale-response suppression
- country, currency-name, and currency-code search filtering
- locale-aware decimal parsing, editing, synchronization, and formatting
- sending-limit, connectivity, and generic conversion error states

There are no UI or snapshot tests and no coverage percentage is claimed.

## Known API behavior

Live verification showed that the API truncates fractional amounts for every supported directed currency pair. The client therefore accepts only whole amounts for conversion and rejects fractional values before networking rather than displaying a result calculated for a different amount.

## Trade-offs and scope

- The UI stays close to the supplied design while keeping SwiftUI components focused and composable.
- No external libraries or unnecessary architecture layers were introduced.
- No CI workflow was added; none is currently present in the repository.
- The implementation prioritizes business rules, testability, and maintainability within the assignment scope.

## Future improvements

- Add UI or snapshot tests for critical presentation states.
- Add a CI workflow for package tests and the host-app build.
- Provide richer retry controls for transient service failures.
- Add localized resources beyond the current English strings.

## AI usage

AI was used to accelerate implementation, review, and test generation. All generated changes were manually reviewed, behavior was manually tested, and the architecture and implementation decisions were validated by the author.
