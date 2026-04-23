# DCR Country Scoping

## Concept

Country scoping allows organizations operating in multiple countries to manage DCR field governance differently per country. A field can be governed globally (all countries) or scoped to a specific country.

```mermaid
flowchart TD
    A[User edits a field] --> B{Is field a managed field?}
    B -->|No| Z[No DCR generated]
    B -->|Yes| C{Does managed field have a CountryId?}
    C -->|No — Global| D[DCR generated for all users]
    C -->|Yes — Country-scoped| E{Does user's PreferredCountry match?}
    E -->|Yes| F[DCR generated]
    E -->|No| Z
```

## Global vs. Country-Scoped Fields

| | Global Field | Country-Scoped Field |
|---|---|---|
| **CountryId** | Blank / null | Set to a specific LifeSciCountry |
| **Applies to** | All users regardless of country | Only users whose PreferredCountry matches |
| **Use case** | Fields that must be governed everywhere | Fields with country-specific regulations |
| **Admin LWC badge** | Grey "Global" | Blue "Country" |

## How It Works

```mermaid
erDiagram
    LifeSciDataChangeDef ||--o{ LifeSciDataChgDefMngFld : "has managed fields"
    LifeSciDataChgDefMngFld }o--o| LifeSciCountry : "optional CountryId"
    User ||--|| UserAdditionalInfo : "has"
    UserAdditionalInfo }o--o| LifeSciCountry : "PreferredCountry matches IsoCode"

    LifeSciDataChgDefMngFld {
        Id Id
        Id LifeSciDataChgDefId
        string FieldApiName
        Id CountryId "null = Global"
        string ValidationType
        boolean ShouldApplyChngImmediately
    }
    LifeSciCountry {
        Id Id
        string MasterLabel "e.g. USA"
        string IsoCode "e.g. US"
    }
    UserAdditionalInfo {
        Id Id
        Id UserId
        string PreferredCountry "e.g. US"
    }
```

### The matching chain

```mermaid
sequenceDiagram
    participant User
    participant DCR Engine
    participant ManagedField as LifeSciDataChgDefMngFld
    participant Country as LifeSciCountry
    participant UAI as UserAdditionalInfo

    User->>DCR Engine: Saves record change
    DCR Engine->>ManagedField: Is this field managed?
    ManagedField-->>DCR Engine: Yes (CountryId = null)
    Note over DCR Engine: Global field — skip country check
    DCR Engine->>DCR Engine: Generate DCR

    User->>DCR Engine: Saves record change
    DCR Engine->>ManagedField: Is this field managed?
    ManagedField-->>DCR Engine: Yes (CountryId = 1TkHs...)
    DCR Engine->>Country: What IsoCode for this CountryId?
    Country-->>DCR Engine: US
    DCR Engine->>UAI: What is user's PreferredCountry?
    UAI-->>DCR Engine: US
    Note over DCR Engine: Match — generate DCR

    User->>DCR Engine: Saves record change
    DCR Engine->>ManagedField: Is this field managed?
    ManagedField-->>DCR Engine: Yes (CountryId = 1TkHs... → US)
    DCR Engine->>UAI: What is user's PreferredCountry?
    UAI-->>DCR Engine: IN
    Note over DCR Engine: No match — skip, no DCR
```

## Country Scoping Across Config Layers

Country scoping applies to managed fields and record type mappings, but NOT to persona definitions:

```mermaid
graph LR
    subgraph "Country-Scopeable"
        MF[LifeSciDataChgDefMngFld<br/>CountryId field]
        RT[LifeSciDataChgDefRecType<br/>CountryId field]
    end
    subgraph "Not Country-Scopeable"
        PD[LifeSciDataChgPersonaDef<br/>No CountryId field]
    end

    MF ---|"Optional"| LC[LifeSciCountry]
    RT ---|"Optional"| LC
```

| Config Record | Has CountryId? | Behavior when set | Behavior when blank |
|---|---|---|---|
| `LifeSciDataChgDefMngFld` | Yes | Only governs this field for users in that country | Governs this field for all users |
| `LifeSciDataChgDefRecType` | Yes | Only applies this record type routing for that country | Applies for all countries |
| `LifeSciDataChgPersonaDef` | No | N/A | Always applies globally per profile |

## Example: Multi-Country Setup

An organization operates in the US and India. They want:
- `ProfessionalTitle` governed in both countries (different validation)
- `ProviderType` governed only in the US
- `ProviderClass` governed only in India

```mermaid
graph TD
    subgraph "HealthcareProvider Definition"
        subgraph "Global Fields"
            G1["(none in this example)"]
        end
        subgraph "US-Scoped Fields"
            US1[ProfessionalTitle<br/>CountryId = USA<br/>Validation = Internal]
            US2[ProviderType<br/>CountryId = USA<br/>Validation = Internal]
        end
        subgraph "India-Scoped Fields"
            IN1[ProfessionalTitle<br/>CountryId = India<br/>Validation = External]
            IN2[ProviderClass<br/>CountryId = India<br/>Validation = External]
        end
    end

    style US1 fill:#d4edfc,color:#0176d3
    style US2 fill:#d4edfc,color:#0176d3
    style IN1 fill:#fde8d0,color:#a96404
    style IN2 fill:#fde8d0,color:#a96404
```

Notice that `ProfessionalTitle` appears twice — once scoped to US (Internal validation) and once scoped to India (External validation). This allows the same field to have different governance rules per country.

### What each user sees

| User | PreferredCountry | Edits ProfessionalTitle | Edits ProviderType | Edits ProviderClass |
|---|---|---|---|---|
| US rep | US | DCR (Internal) | DCR (Internal) | No DCR |
| India rep | IN | DCR (External) | No DCR | DCR (External) |

## Versus Global Fields

If you want a field governed the same way everywhere, create a **single global managed field** (no CountryId):

```mermaid
graph TD
    subgraph "Account Definition"
        subgraph "Global Fields"
            G1[Name<br/>CountryId = null<br/>Validation = Internal]
            G2[PersonGender<br/>CountryId = null<br/>Validation = Internal]
        end
    end

    style G1 fill:#e8e8e8,color:#706e6b
    style G2 fill:#e8e8e8,color:#706e6b
```

All users, regardless of country, generate DCRs when editing these fields.

## Admin LWC Behavior

The DCR Field Manager admin LWC uses the Country dropdown to control what's displayed:

```mermaid
flowchart LR
    subgraph "Country = All Countries"
        A1[Shows ALL managed fields<br/>No scope badge displayed]
    end
    subgraph "Country = USA"
        B1[Shows global fields<br/>Grey 'Global' badge]
        B2[Shows US-scoped fields<br/>Blue 'Country' badge]
    end
```

- **All Countries** — Shows every managed field across all definitions. No scope badge. Toggling a field on creates a **global** managed field (no CountryId).
- **Specific country** — Shows global fields plus fields scoped to that country. Toggling a field on creates a **country-scoped** managed field with the selected country's Id.

## Common Pitfalls

### 1. User's PreferredCountry must match a LifeSciCountry record

Even for global fields, the DCR engine resolves the user's `PreferredCountry` against `LifeSciCountry` records. If no matching record exists, DCRs are silently skipped.

```mermaid
flowchart TD
    A[User's PreferredCountry = IN] --> B{LifeSciCountry with IsoCode = IN exists?}
    B -->|Yes| C[DCR engine proceeds normally]
    B -->|No| D[All DCR processing skipped silently]
    style D fill:#fde8d0,color:#a96404
```

### 2. Duplicate field with different countries

You can have the same field managed twice — once global and once country-scoped, or scoped to two different countries. The DCR engine evaluates each managed field record independently. This can result in **multiple DCRs** for a single field change if the user matches more than one.

### 3. Country filter only affects managed fields

Record type mappings (`LifeSciDataChgDefRecType`) also support `CountryId`, but persona definitions (`LifeSciDataChgPersonaDef`) do not. When planning a multi-country rollout, remember that profile-based behavior is always global.
