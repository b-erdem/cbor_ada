# Security Policy & Threat Model

## Reporting Vulnerabilities

Report security issues privately via GitHub Security Advisories or email
`baris@erdem.dev`. Do not open public issues for vulnerabilities.

## Threat Model

**Trust boundary**: `cbor_ada` assumes all input to `Decode` / `Decode_All` is
untrusted. The library is designed to safely process adversarial CBOR without
crashes, undefined behavior, or memory corruption.

### What SPARK proves (Level 2)

All 517 proof obligations are discharged, guaranteeing **absence of**:

| Class | Coverage |
|---|---|
| Buffer overflows | Array index checks on every access |
| Integer overflows | Arithmetic checks on all computations |
| Range violations | Subtype constraint checks throughout |
| Uninitialized reads | Data flow analysis ensures initialization |
| Division by zero | Preconditions and flow analysis |

These guarantees hold for **all possible inputs** — not just tested ones.

### Well-formedness checks (decoder)

The decoder rejects malformed CBOR per RFC 8949:

- Reserved additional information values (28, 29, 30)
- Non-shortest-form integer encodings
- Simple values 24–31 in two-byte form (Section 3.3)
- Indefinite-length encoding on major types 0, 1, 6
- Break code outside indefinite-length containers
- Indefinite-length string chunks with mismatched major type
- Indefinite-length maps with odd item count at break
- Truncated input (incomplete headers or payloads)
- Standalone break (0xFF) at top level

### Resource exhaustion protections

| Control | Default | Configurable |
|---|---|---|
| Maximum nesting depth | 16 | `Max_Depth` parameter (0–16) |
| Maximum decoded items | 128 | Compile-time `Max_Decode_Items` |
| Maximum string length | `SE_Offset'Last` | `Max_String_Len` parameter |
| Cumulative indefinite string length | Tracked per container | Checked against `Max_String_Len` |
| No heap allocation | Always | Not configurable |

A crafted input declaring a map with `2^63` entries is rejected immediately
with `Err_Resource_Limit` — no allocation or iteration occurs.

### UTF-8 validation

- Enabled by default (`Check_UTF8 => True`) for `Decode_All` and
  `Decode_All_Strict`
- Validates text string content per RFC 3629
- Rejects overlong encodings, surrogates (U+D800..U+DFFF), and code points
  above U+10FFFF
- Can be disabled (`Check_UTF8 => False`) when input is pre-validated

### Encoder safety

- All encoder output is well-formed, shortest-form CBOR (proved by SPARK)
- `Encode_Text_String` passes raw Latin-1 bytes — characters above 127
  produce invalid UTF-8. Use `Encode_Text_String_UTF8` for non-ASCII content.
- Postconditions on all public encoder functions guarantee output length bounds

### Out of scope

The following are **not** protected against by this library:

- **Semantic validity**: The library validates well-formedness (Layer 1) but
  does not enforce application-level schemas, tag semantics, or value
  constraints (Layer 2+). Applications must validate decoded values against
  their expected schema.
- **Side-channel attacks**: Timing and power analysis resistance is not a
  design goal. Do not use for constant-time cryptographic operations.
- **Denial of service via valid input**: A valid CBOR payload with 128 nested
  arrays and maximum-length strings will be decoded successfully. Applications
  should set appropriate `Max_Depth`, `Max_String_Len`, and item count limits.

### Runtime hardening

The library GPR enables:
- `-gnato` — overflow checks (defense-in-depth beyond SPARK proofs)
- `-gnatVa` — validity checks on all parameters

Internal SPARK contracts (`Pre`/`Post`) are **proof-only** and not checked at
runtime in the library build. Enable `-gnata` in your application's GPR to
enforce public API preconditions at runtime.
