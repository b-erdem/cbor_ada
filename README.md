# cbor_ada

A CBOR ([RFC 8949](https://www.rfc-editor.org/rfc/rfc8949)) encoding and decoding library for Ada 2022, built with [SPARK](https://www.adacore.com/about-spark) formal verification.

The encoder and decoder are **100% SPARK-proved** at Level 2 — mathematically guaranteed free of runtime errors (no buffer overflows, no range violations, no integer overflows, no uninitialized reads).

## Key properties

- **Formally verified** — 486 proof obligations, 0 unproved (CVC5/Z3)
- **RFC 8949 compliant** — full well-formedness validation with shortest-form checking
- **No heap allocation** — stack-only, suitable for embedded and safety-critical systems
- **Stateless** — `pragma Pure`, no global state, no side effects
- **Zero dependencies** — only the Ada standard library

## Installation

```bash
alr with cbor_ada
```

Or add to your `alire.toml`:

```toml
[[depends-on]]
cbor_ada = "~0.1.0"
```

## Quick start

### Encoding

```ada
with Ada.Streams;  use Ada.Streams;
with CBOR.Encoding;

procedure Example is
   package Enc renames CBOR.Encoding;
begin
   --  Integers
   Enc.Encode_Unsigned (42);       --  major type 0
   Enc.Encode_Negative (9);        --  major type 1: encodes -10
   Enc.Encode_Integer (-10);       --  auto-selects: same as above

   --  Strings
   Enc.Encode_Text_String ("hello");
   Enc.Encode_Text_String_UTF8 (UTF8_Bytes);  --  raw UTF-8 bytes
   Enc.Encode_Byte_String (Raw_Data);

   --  Containers (header + elements)
   declare
      Output : constant Stream_Element_Array :=
        Enc.Encode_Array (3)
        & Enc.Encode_Unsigned (1)
        & Enc.Encode_Text_String ("two")
        & Enc.Encode_Bool (True);
   begin
      null;
   end;

   --  Maps, tags, simple values, floats, indefinite-length — all supported
end Example;
```

### Decoding

```ada
with Ada.Streams;  use Ada.Streams;
with CBOR;         use CBOR;
with CBOR.Decoding;

procedure Example is
   Input : constant Stream_Element_Array := ...;
begin
   --  Single item
   declare
      R : constant Decode_Result := Decoding.Decode (Input);
   begin
      if R.Status = OK then
         case R.Item.Kind is
            when MT_Unsigned_Integer => ...  --  R.Item.UInt_Value
            when MT_Text_String     => ...  --  Decoding.Get_String (Input, R.Item.TS_Ref)
            when others             => ...
         end case;
      end if;
   end;

   --  Full item tree (arrays, maps, tags expanded)
   declare
      R : constant Decode_All_Result := Decoding.Decode_All (Input);
   begin
      --  R.Items (1 .. R.Count) in depth-first order
      --  R.Next = first unconsumed byte position
      null;
   end;

   --  Walk manually
   declare
      R1 : constant Decode_Result := Decoding.Decode (Input);
      R2 : constant Decode_Result := Decoding.Decode (Input, R1.Next);
   begin
      null;
   end;
end Example;
```

### Security options for untrusted input

```ada
--  Reject trailing bytes after the top-level item
R := Decoding.Decode_All_Strict (Input);

--  Limit nesting depth (default: 16)
R := Decoding.Decode_All (Input, Max_Depth => 4);

--  Limit string lengths (default: no limit)
R := Decoding.Decode_All (Input, Max_String_Len => 4096);

--  Validate UTF-8 in text strings
R := Decoding.Decode_All (Input, Check_UTF8 => True);
```

## Well-formedness validation

The decoder enforces all RFC 8949 well-formedness requirements:

| Check | Reference |
|-------|-----------|
| Reserved additional information 28-30 rejected | Section 3 |
| Simple values 0-31 in two-byte form rejected | Section 3.3 |
| Shortest-form encoding required for all arguments | Section 4.1 |
| Indefinite-length rejected for major types 0, 1, 6 | Section 3.2.6 |
| Break code rejected outside indefinite-length containers | Section 3.2.1 |
| Indefinite-length string chunks must match parent type | Section 3.2.3 |
| Indefinite-length maps must have even item count | Section 3.2.2 |
| Truncated input detected | - |

## Error codes

| Status | Meaning |
|--------|---------|
| `OK` | Successful decode |
| `Err_Not_Well_Formed` | RFC 8949 well-formedness violation |
| `Err_Truncated` | Input ends mid-item |
| `Err_Trailing_Data` | Extra bytes after top-level item (strict mode) |
| `Err_Depth_Exceeded` | Nesting exceeds `Max_Depth` (configurable, default 16) |
| `Err_Invalid_UTF8` | Invalid UTF-8 in text string (`Check_UTF8 => True`) |
| `Err_Too_Many_Items` | Item tree exceeds 128 items |
| `Err_String_Too_Long` | String length exceeds `Max_String_Len` |
| `Err_Resource_Limit` | Map entry count too large to track |

## SPARK proof status

```
SPARK Analysis results   Total   Flow   Provers   Unproved
Run-time Checks            322      .       322          .
Assertions                  68      .        68          .
Functional Contracts        46      .        46          .
Termination                 44     41         3          .
Total                      486     47       439          .
```

All 486 checks proved. No `pragma Assume` or `Justified` annotations — every obligation is machine-verified.

### Running proofs locally

```bash
# Prove core packages (~30 seconds)
scripts/prove

# Prove everything including round-trip lemmas (slow)
scripts/prove 2 120 all
```

## Encoder API reference

| Function | Description |
|----------|-------------|
| `Encode_Unsigned (Value)` | Major type 0 — unsigned integer (0 to 2^64-1) |
| `Encode_Negative (Arg)` | Major type 1 — negative integer (-1 - Arg) |
| `Encode_Integer (Value)` | Signed integer — auto-selects type 0 or 1 |
| `Encode_Byte_String (Data)` | Major type 2 — definite-length byte string |
| `Encode_Text_String (Text)` | Major type 3 — text string (Latin-1 bytes) |
| `Encode_Text_String_UTF8 (Data)` | Major type 3 — text string from raw UTF-8 bytes |
| `Encode_Array (Count)` | Major type 4 — definite-length array header |
| `Encode_Map (Count)` | Major type 5 — definite-length map header |
| `Encode_Tag (Tag_Number)` | Major type 6 — semantic tag |
| `Encode_Simple (Value)` | Major type 7 — simple value (0-23, 32-255) |
| `Encode_Bool (Value)` | Boolean (simple values 20/21) |
| `Encode_Null` | Null (simple value 22) |
| `Encode_Undefined` | Undefined (simple value 23) |
| `Encode_Float_Half (Bytes)` | Half-precision float (2 raw bytes) |
| `Encode_Float_Single (Bytes)` | Single-precision float (4 raw bytes) |
| `Encode_Float_Double (Bytes)` | Double-precision float (8 raw bytes) |
| `Encode_Array_Start` | Indefinite-length array (0x9F) |
| `Encode_Map_Start` | Indefinite-length map (0xBF) |
| `Encode_Byte_String_Start` | Indefinite-length byte string (0x5F) |
| `Encode_Text_String_Start` | Indefinite-length text string (0x7F) |
| `Encode_Break` | Break stop code (0xFF) |

## Limitations

- Float values are opaque byte arrays (no IEEE 754 conversion)
- `Encode_Text_String` passes through Latin-1 bytes; use `Encode_Text_String_UTF8` for pre-encoded UTF-8
- `Decode_All` returns at most 128 items; use manual `Decode` + `Next` walking for larger structures
- Tag content semantics (e.g., tag 0 date format) are not validated
- UTF-8 validation is opt-in (`Check_UTF8 => True`)

## Requirements

- **GNAT** >= 15.1 with Ada 2022 support
- **gnatprove** >= 15.1 (for running SPARK proofs only — not a library dependency)
- **Alire** >= 2.0 (package manager)

## License

Apache-2.0 — see [LICENSE](LICENSE).

Certification artifacts, safety case documentation, and formal verification evidence packages available for safety-critical deployments — contact [baris@erdem.dev](mailto:baris@erdem.dev).
