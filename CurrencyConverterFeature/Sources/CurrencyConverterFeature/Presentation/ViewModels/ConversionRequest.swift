import Foundation

enum ConversionSource: Equatable {
    case sendingAmount
    case receivingAmount
}

struct ConversionRequest {
    let id: UUID
    let fromCurrency: Currency
    let toCurrency: Currency
    let amount: Decimal
    let purpose: ConversionRequestPurpose
    let preservesSendingLimitError: Bool
}

enum ConversionRequestPurpose {
    case conversion(ConversionSource)
    case referenceRate
}
