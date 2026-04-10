import Foundation

enum TaxCountry: String, CaseIterable, Identifiable {
    // Europe
    case spain, portugal, france, germany, italy, netherlands, belgium, austria
    case ireland, uk, switzerland, sweden, norway, denmark, finland, poland
    case czechRepublic, romania, greece, hungary, croatia, bulgaria, slovakia, slovenia
    case lithuania, latvia, estonia, luxembourg, malta, cyprus
    // Americas
    case usa, canada, mexico, brazil, argentina, colombia, chile
    // Asia-Pacific
    case india, japan, australia, newZealand, singapore, hongKong, southKorea
    // Middle East & Africa
    case uae, israel, southAfrica

    var id: String { rawValue }

    var flag: String {
        switch self {
        case .spain: return "🇪🇸"
        case .portugal: return "🇵🇹"
        case .france: return "🇫🇷"
        case .germany: return "🇩🇪"
        case .italy: return "🇮🇹"
        case .netherlands: return "🇳🇱"
        case .belgium: return "🇧🇪"
        case .austria: return "🇦🇹"
        case .ireland: return "🇮🇪"
        case .uk: return "🇬🇧"
        case .switzerland: return "🇨🇭"
        case .sweden: return "🇸🇪"
        case .norway: return "🇳🇴"
        case .denmark: return "🇩🇰"
        case .finland: return "🇫🇮"
        case .poland: return "🇵🇱"
        case .czechRepublic: return "🇨🇿"
        case .romania: return "🇷🇴"
        case .greece: return "🇬🇷"
        case .hungary: return "🇭🇺"
        case .croatia: return "🇭🇷"
        case .bulgaria: return "🇧🇬"
        case .slovakia: return "🇸🇰"
        case .slovenia: return "🇸🇮"
        case .lithuania: return "🇱🇹"
        case .latvia: return "🇱🇻"
        case .estonia: return "🇪🇪"
        case .luxembourg: return "🇱🇺"
        case .malta: return "🇲🇹"
        case .cyprus: return "🇨🇾"
        case .usa: return "🇺🇸"
        case .canada: return "🇨🇦"
        case .mexico: return "🇲🇽"
        case .brazil: return "🇧🇷"
        case .argentina: return "🇦🇷"
        case .colombia: return "🇨🇴"
        case .chile: return "🇨🇱"
        case .india: return "🇮🇳"
        case .japan: return "🇯🇵"
        case .australia: return "🇦🇺"
        case .newZealand: return "🇳🇿"
        case .singapore: return "🇸🇬"
        case .hongKong: return "🇭🇰"
        case .southKorea: return "🇰🇷"
        case .uae: return "🇦🇪"
        case .israel: return "🇮🇱"
        case .southAfrica: return "🇿🇦"
        }
    }

    var displayName: String {
        switch self {
        case .spain: return "Spain"
        case .portugal: return "Portugal"
        case .france: return "France"
        case .germany: return "Germany"
        case .italy: return "Italy"
        case .netherlands: return "Netherlands"
        case .belgium: return "Belgium"
        case .austria: return "Austria"
        case .ireland: return "Ireland"
        case .uk: return "United Kingdom"
        case .switzerland: return "Switzerland"
        case .sweden: return "Sweden"
        case .norway: return "Norway"
        case .denmark: return "Denmark"
        case .finland: return "Finland"
        case .poland: return "Poland"
        case .czechRepublic: return "Czech Republic"
        case .romania: return "Romania"
        case .greece: return "Greece"
        case .hungary: return "Hungary"
        case .croatia: return "Croatia"
        case .bulgaria: return "Bulgaria"
        case .slovakia: return "Slovakia"
        case .slovenia: return "Slovenia"
        case .lithuania: return "Lithuania"
        case .latvia: return "Latvia"
        case .estonia: return "Estonia"
        case .luxembourg: return "Luxembourg"
        case .malta: return "Malta"
        case .cyprus: return "Cyprus"
        case .usa: return "United States"
        case .canada: return "Canada"
        case .mexico: return "Mexico"
        case .brazil: return "Brazil"
        case .argentina: return "Argentina"
        case .colombia: return "Colombia"
        case .chile: return "Chile"
        case .india: return "India"
        case .japan: return "Japan"
        case .australia: return "Australia"
        case .newZealand: return "New Zealand"
        case .singapore: return "Singapore"
        case .hongKong: return "Hong Kong"
        case .southKorea: return "South Korea"
        case .uae: return "UAE"
        case .israel: return "Israel"
        case .southAfrica: return "South Africa"
        }
    }

    var taxIdLabel: String {
        switch self {
        case .spain: return "NIF / CIF"
        case .portugal: return "NIF"
        case .france: return "SIRET / SIREN"
        case .germany: return "Steuernummer"
        case .italy: return "Codice Fiscale / P.IVA"
        case .uk: return "UTR / VAT"
        case .usa: return "EIN / SSN"
        case .canada: return "BN / GST"
        case .mexico: return "RFC"
        case .brazil: return "CNPJ / CPF"
        case .argentina: return "CUIT"
        case .colombia: return "NIT"
        case .chile: return "RUT"
        case .india: return "GSTIN / PAN"
        case .japan: return "Corporate Number"
        case .australia: return "ABN"
        case .newZealand: return "IRD / NZBN"
        case .singapore: return "UEN"
        case .hongKong: return "BR Number"
        case .southKorea: return "BRN"
        case .uae: return "TRN"
        case .israel: return "Company ID"
        case .southAfrica: return "Tax Number"
        case .switzerland: return "UID / MWST"
        default: return "VAT Number"
        }
    }

    var taxIdPlaceholder: String {
        switch self {
        case .spain: return "B12345678"
        case .portugal: return "PT123456789"
        case .france: return "FR12345678901"
        case .germany: return "DE123456789"
        case .italy: return "IT12345678901"
        case .uk: return "GB123456789"
        case .usa: return "12-3456789"
        case .canada: return "123456789RC0001"
        case .mexico: return "ABC123456AB1"
        case .brazil: return "12.345.678/0001-90"
        case .argentina: return "20-12345678-9"
        case .colombia: return "900.123.456-7"
        case .chile: return "12.345.678-9"
        case .india: return "22AAAAA0000A1Z5"
        case .japan: return "1234567890123"
        case .australia: return "12 345 678 901"
        case .switzerland: return "CHE-123.456.789"
        default: return "XX123456789"
        }
    }

    var taxIdType: String {
        switch self {
        case .spain: return "NIF"
        case .portugal: return "NIF"
        case .france: return "SIRET"
        case .germany: return "StNr"
        case .italy: return "P.IVA"
        case .uk: return "UTR"
        case .usa: return "EIN"
        case .canada: return "BN"
        case .mexico: return "RFC"
        case .brazil: return "CNPJ"
        case .argentina: return "CUIT"
        case .colombia: return "NIT"
        case .chile: return "RUT"
        case .india: return "GSTIN"
        case .japan: return "CN"
        case .australia: return "ABN"
        case .newZealand: return "IRD"
        case .singapore: return "UEN"
        case .hongKong: return "BR"
        case .southKorea: return "BRN"
        case .uae: return "TRN"
        case .israel: return "CID"
        case .southAfrica: return "TIN"
        case .switzerland: return "UID"
        default: return "VAT"
        }
    }
}
