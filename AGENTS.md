# AGENTS.md — CBOR Ada Project Context

## Project Overview

CBOR (RFC 8949) encoding/decoding library in Ada/SPARK, designed for maximum formal verification. The goal is mathematical proofs of no runtime errors via SPARK/gnatprove. Published to Alire package manager.

- **Author**: Baris Erdem (`baris@erdem.dev`, GitHub `b-erdem`)
- **License**: AGPL-3.0-or-later (commercial licensing available)
- **Repo** (not yet pushed): `b-erdem/cbor_ada`

## Toolchain

- **Alire** v2.1.0 at `~/.local/bin/alr`
- **GNAT** Native 15.2.1, gprbuild 25.0.1, gnatprove 15.1.0
- macOS arm64 — GNAT is x86_64 (Rosetta). Linking requires `-L` flag to macOS SDK in `test_cbor.gpr`

## Commands

```bash
export PATH="$HOME/.local/bin:$PATH"

# Build library
alr build

# Build tests
alr exec -- gprbuild -P test_cbor.gpr -p

# Run tests
./bin/test_cbor

# Run SPARK proofs (level 1, 120s timeout)
alr exec -- gnatprove -P cbor_ada.gpr -j0 --level=1 --timeout=120

# Check proof summary
grep "Total " obj/gnatprove/gnatprove.out

# Detailed unproved checks
cat obj/gnatprove/cbor-decoding.adb.stderr
```

## File Structure

```
cbor_ada/
├── alire.toml              # Package manifest (AGPL-3.0-or-later)
├── cbor_ada.gpr            # Library project (static, Ada 2022)
├── test_cbor.gpr           # Test project (macOS SDK linker flags)
├── src/
│   ├── cbor.ads            # Core types: Major_Type, CBOR_Item (variant record), Decode_Status, etc.
│   ├── cbor-encoding.ads   # Encoder spec — pre/postconditions, Head_Length expression function
│   ├── cbor-encoding.adb   # Encoder body — 100% proved (142/142 at Level 2)
│   ├── cbor-decoding.ads   # Decoder spec: Decode, Get_String, Decode_All, Is_Valid_UTF8, Head_Size
│   └── cbor-decoding.adb   # Decoder body — ~96% proved (411/428 at Level 1)
├── test/
│   └── test_cbor.adb       # 157 tests across 26 test procedures
└── LICENSE                  # AGPL-3.0 full text
```

## Architecture

### cbor.ads — Core Types

- `Major_Type` enum: MT_Unsigned_Integer through MT_Simple_Value
- `CBOR_Item`: variant record discriminated on `Kind`. Each variant has specific fields:
  - `UInt_Value`, `NInt_Arg`, `BS_Ref`, `TS_Ref`, `Arr_Count`, `Map_Count`, `Tag_Number`, `SV_Value` + `Float_Ref`
- `String_Ref`: `(First, Length)` pointing into source buffer
- `Null_Ref`: `(First => 1, Length => 0)`
- `Decode_Result`: `(Status, Item, Offset)`
- `Decode_All_Result`: `(Status, Items, Count, Last_Pos)`
- `Max_Nesting_Depth = 16`, `Max_Decode_Items = 128`
- `MT_To_U8` / `U8_To_MT`: SPARK-compatible expression functions (replaces `'Val`/`'Pos` which aren't SPARK-compatible)

### cbor-encoding — Encoder (100% proved)

- All functions produce well-formed, shortest-form CBOR
- `Head_Length` is an expression function in the spec (required for SPARK to prove postconditions)
- `Append_All` pattern for SPARK-provable array concatenation
- Functions: `Encode_Unsigned`, `Encode_Negative`, `Encode_Text_String`, `Encode_Byte_String`, `Encode_Array`, `Encode_Map`, `Encode_Tag`, `Encode_Bool`, `Encode_Null`, `Encode_Undefined`, `Encode_Simple`, `Encode_Float_Half`, `Encode_Float_Single`, `Encode_Float_Double`, `Encode_Array_Start`, `Encode_Map_Start`, `Encode_Byte_String_Start`, `Encode_Text_String_Start`, `Encode_Break`

### cbor-decoding — Decoder (~96% proved)

**Key functions:**
- `Decode(Data, Pos)`: Single-item decode. `Pos=0` means `Data'First`. Returns `Decode_Result`.
- `Head_Size(AI)`: Returns 1|2|3|5|9 with postcondition.
- `Get_String(Data, Ref)`: Extract string content. Returns `(1 .. Ref.Length)` array. Works for empty strings.
- `Decode_All(Data, Check_UTF8)`: Iterative stack-based tree decode. Max depth 16.
- `Is_Valid_UTF8(Data)`: Full RFC 3629 validation.

**Internal structure of Decode:**
1. Extract `B`, `MT`, `AI` from byte at `P`
2. Reject AI 28-30 (reserved)
3. Handle AI=31 (indefinite-length starts for arrays/maps/strings; break rejected at top level)
4. `Has_Head` check (ensures enough bytes for the head)
5. `Read_Arg` to decode the argument value
6. Major-type-specific processing with well-formedness validation

**Internal structure of Decode_All:**
1. Decode first item
2. If container, push onto stack
3. Loop: peek for break (0xFF) inside indefinite containers OR decode next item
4. Pop containers when their item count is exhausted
5. Detect truncation if loop exits with `Depth > 0`

**Local functions in Decode_All (expression functions with preconditions):**
- `Raw_AI(Item)`, `Raw_MT(Item)`: Read from `Data(Item.Head_Start)`. Require `Item.Head_Start in Data'Range`.
- `Is_Container(Item)`: Checks if item opens a new nesting level.
- `Handle_Container(Item)`: Pushes to stack, handles depth checks.
- `Validate_Chunk(Item, Parent, Valid)`: Checks chunk type matches parent for indefinite strings.
- `Pop_And_Propagate`: Decrements `Remaining`, pops exhausted containers.

## SPARK Proof Strategy

### What's proved
- **Encoder**: 100% (142/142 at Level 2)
- **Decoder**: ~96% (411/428 at Level 1)
- All overflow checks pass thanks to overflow-safe arithmetic

### Key techniques used
- **Overflow-safe arithmetic**: `Data'Last - Pos >= N - 1` instead of `Pos + N <= Data'Last`
- **Preconditions**: `Data'First >= 0` and `Data'Last <= Max_Data_Length` on all public functions
- **Postconditions on Decode**: `Head_Start in Data'Range`, `Head_End in Data'Range`, `TS_Ref.First >= Data'First` etc.
- **Head_Size postcondition**: `Result in 1 | 2 | 3 | 5 | 9`
- **Expression functions**: `Has_Head`, `Raw_AI`, `Raw_MT`, `Is_Container` — easier for SPARK to inline
- **Loop invariants**: Track `Depth`, `Pos`, `Result.Count`, `Data'First >= 0`, `Data'Last <= Max_Data_Length`

### 17 unproved checks (known, safe by manual analysis)

All in `cbor-decoding.adb`. Categories:

1. **Read_Arg array index (4)**: `Data(Pos+1/2/4/8)` — SPARK can't derive array bounds from `Has_Head` precondition through `Head_Size` function calls. Safe because `Has_Head` guarantees `Data'Last - Pos >= Head_Size(AI) - 1`.
2. **Decode simple value (1)**: `Data(P+1)` when `AI=24` — same issue.
3. **Stack(Depth) index (3)**: In `Pop_And_Propagate` inlined calls — `Depth >= 1` from loop invariant not propagated through inlining.
4. **Handle_Container Stack(Depth) (1)**: After `Push`, `Depth <= Max_Nesting_Depth` not tracked.
5. **Get_String/Is_Valid_UTF8 preconditions (4)**: `Ref.First >= Data'First`, `Data'First >= 0` — Decode's postconditions not fully propagated through Decode_All loop.
6. **Decode_All loop invariants (4)**: `Depth <= Max_Nesting_Depth`, `Result.Count >= 1`, `Result.Count < Max_Decode_Items` — not preserved/established because SPARK can't track `Handle_Container` side effects on `Depth` and `Result.Count`.

### What NOT to do
- **Don't use `pragma Overflow_Mode`**: Ignored by gnatprove, only affects runtime.
- **Don't use `'Val`/`'Pos` on enums**: Not SPARK-compatible. Use `MT_To_U8`/`U8_To_MT`.
- **Don't use `Unchecked_Conversion`**: Use direct type conversion (e.g., `Unsigned_8(Data(I))`).
- **Don't add assertions SPARK can't prove**: Each failed assertion adds to unproved count. Only add assertions SPARK can actually use.
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
- `SV_Value = 20/21/22/23` → false/true/null/undefined
- `SV_Value = 25/26/27` → half/single/double float; payload bytes in `Float_Ref`
- `SV_Value = 31` → break (only appears inside Decode_All's indefinite containers)
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
