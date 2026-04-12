# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2026-04-13

Safety-critical hardening release based on comprehensive security review.

### Fixed

- **Critical**: Stale cumulative length tracking for indefinite-length strings
  at the same nesting depth (reset `Indef_Str_Len` on `Push`)
- UTF-8 validation now avoids unnecessary stack copy (direct slice to
  `Is_Valid_UTF8`)

### Added

- `Post` contracts on all public encoder functions (length bounds)
- `Post` contracts on `Decode_All` / `Decode_All_Strict` (count bounds)
- `Post` contracts on all float round-trip lemmas
- Runtime hardening: `-gnato` (overflow checks) and `-gnatVa` (validity
  checks) in library GPR
- SPARK proofs now run on pull requests in CI (not just push)
- `SECURITY.md` — threat model, resource limits, hardening documentation
- 21 new test cases: reserved AI values, indefinite-length on invalid major
  types, empty input, resource limits, stale cumulative length regression,
  empty indefinite containers

### Changed

- `Check_UTF8` default changed from `False` to `True` for `Decode_All` and
  `Decode_All_Strict` (safer default for untrusted input)
- Proof obligations increased from 486 to 517 (0 unproved)
- Test count increased from 676 to 697

## [0.1.0] - 2026-04-10

Initial release.

### Added

- **Encoder** — all 8 CBOR major types (RFC 8949)
  - `Encode_Unsigned`, `Encode_Negative`, `Encode_Integer` (signed)
  - `Encode_Byte_String`, `Encode_Text_String`, `Encode_Text_String_UTF8`
  - `Encode_Array`, `Encode_Map`, `Encode_Tag`
  - `Encode_Simple`, `Encode_Bool`, `Encode_Null`, `Encode_Undefined`
  - `Encode_Float_Half`, `Encode_Float_Single`, `Encode_Float_Double`
  - Indefinite-length containers: `Encode_Array_Start`, `Encode_Map_Start`,
    `Encode_Byte_String_Start`, `Encode_Text_String_Start`, `Encode_Break`
- **Decoder** — single-item and full-tree decoding
  - `Decode` — single CBOR item with manual walking via `Next`
  - `Decode_All` — full item tree (up to 128 items) with configurable
    `Max_Depth`, `Max_String_Len`, and `Check_UTF8`
  - `Decode_All_Strict` — rejects trailing bytes after the top-level item
- **Well-formedness validation** — all RFC 8949 requirements enforced
  - Reserved additional information values 28–30 rejected
  - Two-byte simple values 0–31 rejected
  - Shortest-form encoding required for all arguments
  - Indefinite-length rejected for major types 0, 1, 6
  - Break code rejected outside indefinite-length containers
  - Indefinite-length string chunk type matching
  - Indefinite-length map even-count enforcement
  - Truncated input detection
- **SPARK formal verification** — 517 proof obligations, 0 unproved (Level 2)
- **Security controls** — configurable nesting depth, string length limits,
  optional UTF-8 validation
- No heap allocation, `pragma Pure`, zero dependencies

[0.1.1]: https://github.com/b-erdem/cbor_ada/releases/tag/v0.1.1
[0.1.0]: https://github.com/b-erdem/cbor_ada/releases/tag/v0.1.0
