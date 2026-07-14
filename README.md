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

This is the verified automated test flow and currently runs 86 XCTest cases.

### Xcode tests

Tests included in an active Xcode scheme can be run with **Cmd + U**. The shared `TransferGoCurrencyApp` scheme currently has no explicit test target in its test action, so the package command above is the reliable test path for this repository. No `xcodebuild test` command is documented because one is not configured for that scheme.

## Features

- Live currency conversion using TransferGo FX API
- Bidirectional conversion (send ↔ receive)
- Currency selection with search
- Currency swap with a fresh request for the newly directed pair
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
- **Locale-aware editing:** input uses the current locale's decimal separator and avoids grouping while editing. Positive fractional input is accepted and sent to the FX endpoint as the exact `Decimal` value entered by the user.
- **Stable API serialization:** request amounts use an `en_US_POSIX` representation, independent of the device locale.
- **Latest-request wins:** a new edit or currency change cancels the previous task, and request identifiers prevent stale responses from updating state.
- **Rate-based local calculation:** successful responses must match the requested currency pair and contain a positive rate. The exact requested `Decimal` is multiplied by that rate and rounded to two decimal places; response `fromAmount` and `toAmount` values are not used for the final calculation.
- **Fresh conversion after swap:** currencies and amounts are swapped together and remain visible while a new request runs for the new FROM/TO pair using the exact new FROM amount. Only the fresh current response may replace the displayed rate and converted amount.
- **Explicit state:** the converter ViewModel exposes loading, conversion-rate, and typed error state to keep Views presentation-focused.
- **View-owned presentation:** the converter View owns the active currency-selection sheet; conversion rules remain in the ViewModel.
- **Small package surface:** integration views, domain values, and the service protocol are public while implementation details remain internal.
- **System frameworks only:** SwiftUI, Foundation, Combine, and XCTest are used with no third-party dependencies.

## Error handling

- **Invalid amount:** invalid locale input is rejected by the editing formatter. Positive fractional values are accepted and requested exactly using the locale-aware dot or comma editing path. Non-positive values do not trigger an API request or a sending-limit error.
- **Sending limit exceeded:** the ViewModel exposes the currency-specific limit error and skips a new forward request; the last successful conversion remains visible. Reverse conversions validate the resulting sending amount after the response.
- **Network or conversion failure:** offline and lost-connection errors show a dismissible network banner. Other service, response, or decoding failures show a generic inline conversion error.
- **Cancelled or stale request:** cancellation is ignored, and only the latest request may update displayed state.
- **Zero or empty input:** empty input becomes zero, clears the calculated counterpart and current error, and does not request a conversion. The current pair's displayed rate is retained; changing the pair at zero fetches a one-unit reference rate.

## Testing

The package contains 86 XCTest cases covering:

- supported currencies and sending limits
- FX URL construction, locale-independent amount serialization, response decoding, and transport errors
- initial, forward, and reverse ViewModel conversion behavior
- currency changes, swapping, loading, and latest-request handling
- request cancellation and stale-response suppression
- exact fractional forward and reverse requests, local `Decimal` calculation, and fresh swap responses
- successful-response currency-pair and positive-rate validation
- country, currency-name, and currency-code search filtering
- locale-aware decimal parsing, editing, synchronization, and formatting
- sending-limit, connectivity, and generic conversion error states

There are no UI or snapshot tests and no coverage percentage is claimed.

## Known API behavior

Live verification showed that the API accepts fractional query amounts and returns a valid, consistent rate, while its response `fromAmount` is truncated to an integer and `toAmount` is calculated from that truncated value. The client therefore sends the exact user-entered `Decimal`, validates the returned currency pair and positive rate, and calculates the final amount locally as `requested amount × returned rate`, rounded to two decimal places. It does not use response `fromAmount` or `toAmount` for the final calculation.

## Trade-offs and scope

- The UI stays close to the supplied design while keeping SwiftUI components focused and composable.
- No external libraries or unnecessary architecture layers were introduced.
- No CI workflow was added; none is currently present in the repository.
- The implementation prioritizes business rules, testability, and maintainability within the assignment scope.

## Future improvements

- Add explicit handling for same-currency pairs. The provided design allows selecting the same currency on both sides, and the API returns an identity rate of `1`. In a production version, the opposite selected currency could be disabled in the picker and redundant identity-rate requests could be avoided.
- Add UI or snapshot tests for critical presentation states, including validation errors, loading, network failures, currency selection, and swap behavior.
- Add a CI workflow that runs package tests and verifies both Debug and Release host-app builds.
- Provide richer retry controls for transient service failures, including a visible retry action and clearer distinction between connectivity, timeout, and server errors.
- Add localized resources beyond the current English strings.
- Add explicit cancellation of in-flight conversion requests when the feature is dismissed.
- Improve Dynamic Type support and verify the layout at accessibility text sizes and constrained widths.
- Expand VoiceOver coverage, including descriptive labels, current currency values, focus order, and minimum tap-target sizes.
- Add an application icon and automated validation of the built product’s icon metadata before distribution.
- Refine the public package API so externally injected service implementations can construct and inspect returned domain models without relying on `@testable`.
- Add broader input validation for extremely large pasted values and ensure displayed input always matches the exact value used in a request.

## AI usage

AI was used to accelerate implementation, review, and test generation. All generated changes were manually reviewed, behavior was manually tested, and the architecture and implementation decisions were validated by the author.
