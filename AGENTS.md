# AGENTS.md — CBOR Ada Project Context

## Project Overview

CBOR (RFC 8949) encoding/decoding library in Ada/SPARK, designed for maximum formal verification. The goal is mathematical proofs of no runtime errors via SPARK/gnatprove. Published to Alire package manager.

- **Author**: Baris Erdem (`baris@erdem.dev`, GitHub `b-erdem`)
- **License**: Apache-2.0 (certification/safety evidence packages available)
- **Repo** (not yet pushed): `b-erdem/cbor_ada`

## Toolchain

- **Alire** v2.1.0 at `~/.local/bin/alr`
- **GNAT** Native 15.2.1, gprbuild 25.0.1, gnatprove 15.1.0
- macOS arm64 — GNAT is x86_64 (Rosetta). Linking requires `-L` flag to macOS SDK in `test_cbor.gpr` (conditional on OS)

## Commands

```bash
export PATH="$HOME/.local/bin:$PATH"

# Build library
alr build

# Build tests
alr exec -- gprbuild -P test_cbor.gpr -p

# Run tests
./bin/test_cbor

# Run SPARK proofs (gnatprove is NOT a library dependency; add it first)
alr with gnatprove
alr exec -- gnatprove -P cbor_ada.gpr -j0 --level=2 --timeout=120

# Or use the convenience script (auto-adds/removes gnatprove)
scripts/prove 2 120

# Check proof summary
grep "Total " obj/gnatprove/gnatprove.out

# Detailed unproved checks
cat obj/gnatprove/cbor-decoding.adb.stderr
```

## File Structure

```
cbor_ada/
├── alire.toml              # Package manifest (Apache-2.0, no runtime deps)
├── cbor_ada.gpr            # Library project (static, Ada 2022)
├── test_cbor.gpr           # Test project (cross-platform linker flags)
├── .github/workflows/ci.yml # CI: build + test (Ubuntu/macOS) + SPARK prove
├── src/
│   ├── cbor.ads            # Core types: Major_Type, CBOR_Item, Decode_Status, etc.
│   ├── cbor-encoding.ads   # Encoder spec — pre/postconditions, Head_Length
│   ├── cbor-encoding.adb   # Encoder body — 100% proved
│   ├── cbor-decoding.ads   # Decoder spec: Decode, Get_String, Decode_All, Is_Valid_UTF8
│   ├── cbor-decoding.adb   # Decoder body — 100% proved
│   ├── cbor-properties.ads # Round-trip lemmas spec (Ghost, postconditions)
│   └── cbor-properties.adb # Round-trip lemma bodies
├���─ test/
│   └── test_cbor.adb       # 647+ tests across 40+ test procedures
└── LICENSE                  # Apache-2.0 full text
```

## Architecture

### cbor.ads — Core Types

- `Major_Type` enum: MT_Unsigned_Integer through MT_Simple_Value
- `MT_Encoding` subtype: `Unsigned_8 range 0 .. 7` for `U8_To_MT` parameter
- `CBOR_Item`: variant record discriminated on `Kind`. Each variant has specific fields:
  - `UInt_Value`, `NInt_Arg`, `BS_Ref`, `TS_Ref`, `Arr_Count`, `Map_Count`, `Tag_Number`, `SV_Value` + `Float_Ref`
- `String_Ref`: `(First, Length)` pointing into source buffer
- `Null_Ref`: `(First => 1, Length => 0)`
- `Head_Start` / `Item_End`: byte range in source buffer. `Item_End` is the last byte of the complete item (including string payload)
- `Decode_Result`: `(Status, Item, Offset)`
- `Decode_All_Result`: `(Status, Items, Count, Last_Pos)`
- `Max_Nesting_Depth = 16`, `Max_Decode_Items = 128`
- `MT_To_U8` / `U8_To_MT`: SPARK-compatible expression functions (replaces `'Val`/`'Pos` which aren't SPARK-compatible)

### Decode_Status error codes

- `OK` — success
- `Err_Not_Well_Formed` — RFC 8949 well-formedness violation
- `Err_Truncated` — input cut short
- `Err_Trailing_Data` — extra bytes after top-level item (strict mode only)
- `Err_Depth_Exceeded` — nesting too deep
- `Err_Invalid_UTF8` — bad UTF-8 (when Check_UTF8 => True)
- `Err_Too_Many_Items` — exceeds Max_Decode_Items
- `Err_String_Too_Long` — string exceeds Max_String_Len parameter

### cbor-encoding — Encoder (100% proved)

- All functions produce well-formed, shortest-form CBOR
- `Head_Length` is an expression function in the spec (required for SPARK to prove postconditions)
- `Append_All` pattern for SPARK-provable array concatenation
- `Encode_Simple` takes `Interfaces.Unsigned_8` (not UInt64) with precondition excluding 24-31
- `Encode_Text_String_UTF8`: encodes raw UTF-8 bytes as major type 3 (avoids Latin-1 ambiguity)
- Functions: `Encode_Unsigned`, `Encode_Negative`, `Encode_Text_String`, `Encode_Text_String_UTF8`, `Encode_Byte_String`, `Encode_Array`, `Encode_Map`, `Encode_Tag`, `Encode_Bool`, `Encode_Null`, `Encode_Undefined`, `Encode_Simple`, `Encode_Float_Half`, `Encode_Float_Single`, `Encode_Float_Double`, `Encode_Array_Start`, `Encode_Map_Start`, `Encode_Byte_String_Start`, `Encode_Text_String_Start`, `Encode_Break`

### cbor-decoding — Decoder (100% proved)

**Key functions:**
- `Decode(Data, Pos)`: Single-item decode. `Pos=0` means `Data'First`. Returns `Decode_Result`.
- `Head_Size(AI)`: Returns 1|2|3|5|9 with postcondition.
- `Get_String(Data, Ref)`: Extract string content. Returns `(1 .. Ref.Length)` array. Works for empty strings.
- `Decode_All(Data, Check_UTF8, Max_String_Len)`: Iterative stack-based tree decode. Max depth 16.
- `Decode_All_Strict(Data, Check_UTF8, Max_String_Len)`: Like Decode_All but rejects trailing bytes with `Err_Trailing_Data`.
- `Is_Valid_UTF8(Data)`: Full RFC 3629 validation.

### cbor-properties — Round-trip lemmas (Ghost)

- Ghost procedures with postconditions proving `Decode(Encode(V)).Item = V`
- Covers: unsigned, negative, bool, null, undefined, simple, tag, array, map, float half/single/double
- Postconditions reference `CBOR.Encoding` and `CBOR.Decoding` directly
- Float lemmas use internal assertions (postconditions require Get_String which is harder to express)

## SPARK Proof Strategy

### Key techniques used
- **Overflow-safe arithmetic**: `Data'Last - Pos >= N - 1` instead of `Pos + N <= Data'Last`
- **Preconditions**: `Data'First >= 0` and `Data'Last <= Max_Data_Length` on all public functions
- **Postconditions on Decode**: `Head_Start in Data'Range`, `Item_End in Data'Range`, valid refs
- **Head_Size postcondition**: `Result in 1 | 2 | 3 | 5 | 9`
- **Expression functions**: `Has_Head`, `Raw_AI`, `Raw_MT`, `Is_Container` — easier for SPARK to inline
- **Loop invariants**: Track `Depth`, `Pos`, `Result.Count`, `Data'First >= 0`, `Data'Last <= Max_Data_Length`

### What NOT to do
- **Don't use `pragma Overflow_Mode`**: Ignored by gnatprove, only affects runtime.
- **Don't use `'Val`/`'Pos` on enums**: Not SPARK-compatible. Use `MT_To_U8`/`U8_To_MT`.
- **Don't use `Unchecked_Conversion`**: Use direct type conversion (e.g., `Unsigned_8(Data(I))`).
- **Don't add assertions SPARK can't prove**: Each failed assertion adds to unproved count.
- **Don't use `Data'Length` in preconditions**: Can overflow for large index ranges. Use `Data'Last <= Max_Data_Length` instead.
- **Don't use `SE_Offset'First` as lower bound**: It's `Long_Long_Integer'First` (huge negative). Use `Data'First >= 0`.

## Well-formedness Checks (RFC 8949)

- AI 28-30 rejected (reserved)
- Simple values < 32 in two-byte form rejected (Section 3.3)
- Shortest-form encoding required for all integer arguments
- String length bounded to `SE_Offset'Last`
- Truncated input detected (incomplete heads, strings, containers)
- Indefinite-length for major types 0, 1, 6 rejected
- Break (0xFF) rejected at top level; only valid inside indefinite containers
- Indefinite-length string chunks must match parent major type
- Indefinite-length maps must have even item count at break
- Maximum nesting depth enforced (16)

## CBOR_Item Variant Fields Quick Reference

| Kind                  | Fields                    |
|-----------------------|---------------------------|
| MT_Unsigned_Integer   | `UInt_Value : UInt64`     |
| MT_Negative_Integer   | `NInt_Arg : UInt64`       |
| MT_Byte_String        | `BS_Ref : String_Ref`     |
| MT_Text_String        | `TS_Ref : String_Ref`     |
| MT_Array              | `Arr_Count : UInt64`      |
| MT_Map                | `Map_Count : UInt64`      |
| MT_Tag                | `Tag_Number : UInt64`     |
| MT_Simple_Value       | `SV_Value : Unsigned_8`, `Float_Ref : String_Ref` |

For `MT_Simple_Value`:
- `SV_Value = 20/21/22/23` -> false/true/null/undefined
- `SV_Value = 25/26/27` -> half/single/double float; payload bytes in `Float_Ref`
- `SV_Value = 31` -> break (only appears inside Decode_All's indefinite containers)
- `Float_Ref = Null_Ref` for non-float simple values

## Design Decisions

- **Layer approach**:
  - Layer 1 (fully provable): Full 64-bit unsigned range, string content decoding, well-formedness, bounded nested decoding
  - Layer 2 (provable byte-level): Float as opaque bytes (no IEEE 754 conversion)
  - Layer 3 (acknowledged limits): UTF-8 as runtime check, bignum/tag semantics pass-through
- **No heap allocation**: Stack-only, suitable for embedded
- **`pragma Pure`**: Stateless, no side effects
- **`Stream_Element = Unsigned_8`**: Both are `mod 2**8`, direct type conversion
- **`SE_Offset = Long_Long_Integer`**: 64-bit signed. `Max_Data_Length = SE_Offset'Last / 2` prevents overflow in arithmetic
- **Break handling**: `Decode` rejects top-level break. `Decode_All` peeks for 0xFF directly when inside indefinite containers.
- **`Item_End` naming**: Previously `Head_End`, renamed to reflect that for string types it points past the payload, not just the head bytes.
- **`Err_Trailing_Data` vs `Err_Truncated`**: Separate error codes — truncated means input cut short, trailing data means extra bytes after complete item.
