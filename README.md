# cbor_ada

CBOR (RFC 8949) encoding/decoding library for Ada/SPARK with formal verification.

## Features

- **SPARK-proved encoder** — 100% proved at Level 2 (mathematically guaranteed no runtime errors)
- **Full RFC 8949 well-formedness validation** — shortest-form checking, reserved AI rejection, string length bounds
- **Bounded nested decoding** — iterative stack with configurable max depth (`Max_Depth` parameter, default 16)
- **UTF-8 validation** — optional RFC 3629 checking for text strings
- **All major types** — unsigned/negative integers, byte/text strings, arrays, maps, tags, simple values, floats (opaque), break, indefinite-length starts
- **No heap allocation** — stack-only, suitable for embedded/constrained environments
- **`pragma Pure`** — stateless, no side effects
- **Configurable string length limit** — `Max_String_Len` parameter for DoS protection on untrusted input
- **Round-trip property lemmas** — SPARK ghost proofs that `Decode(Encode(V)) = V`

## Installation

```bash
alr with cbor_ada
```

## Usage

### Encoding

```ada
with CBOR.Encoding;
use CBOR.Encoding;

--  Unsigned integer
Bytes := Encode_Unsigned (42);

--  Negative integer (-1 - Arg)
Bytes := Encode_Negative (9);  --  encodes -10

--  Signed integer (auto-selects major type 0 or 1)
Bytes := Encode_Integer (42);    --  same as Encode_Unsigned (42)
Bytes := Encode_Integer (-10);   --  same as Encode_Negative (9)

--  Text string (Latin-1 bytes; caller ensures valid content)
Bytes := Encode_Text_String ("hello");

--  Text string from raw UTF-8 bytes (preferred for UTF-8 content)
Bytes := Encode_Text_String_UTF8 (UTF8_Bytes);

--  Byte string
Bytes := Encode_Byte_String (Raw_Bytes);

--  Array header followed by elements
Output := Encode_Array (3)
  & Encode_Unsigned (1)
  & Encode_Text_String ("two")
  & Encode_Bool (True);

--  Map header followed by key-value pairs
Output := Encode_Map (1)
  & Encode_Text_String ("key")
  & Encode_Unsigned (42);

--  Tag
Output := Encode_Tag (0) & Encode_Text_String ("2023-01-01");

--  Bool, null, undefined
Encode_Bool (True);   --  0xF5
Encode_Null;           --  0xF6
Encode_Undefined;      --  0xF7

--  Simple values (0-23 and 32-255 only; 24-31 reserved)
Encode_Simple (32);

--  Floats (raw bytes, no conversion)
Encode_Float_Half ([16#3C#, 16#00#]);
Encode_Float_Single ([16#3F#, 16#80#, 16#00#, 16#00#]);
Encode_Float_Double ([16#3F#, 16#F0#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#]);

--  Indefinite-length starts
Encode_Array_Start;          --  0x9F ... Encode_Break
Encode_Map_Start;            --  0xBF ... Encode_Break
Encode_Byte_String_Start;    --  0x5F ... Encode_Break
Encode_Text_String_Start;    --  0x7F ... Encode_Break
Encode_Break;                --  0xFF
```

### Decoding

```ada
with CBOR.Decoding;
with CBOR;
use CBOR;

--  Single-item decode
R : Decode_Result := Decoding.Decode (Input_Bytes);
if R.Status = OK then
   case R.Item.Kind is
      when MT_Unsigned_Integer =>
         Value := R.Item.UInt_Value;
      when MT_Text_String =>
         Text := Decoding.Get_String (Input_Bytes, R.Item.TS_Ref);
      when MT_Array =>
         Count := R.Item.Arr_Count;
      --  ...
   end case;
end if;

--  Decode entire nested structure
R : Decode_All_Result := Decoding.Decode_All (Input_Bytes);
--  R.Items (1 .. R.Count) contains all items in tree order
--  R.Next is the first unconsumed byte position

--  With UTF-8 validation
R := Decoding.Decode_All (Input_Bytes, Check_UTF8 => True);

--  With string length limit (DoS protection for untrusted input)
R := Decoding.Decode_All (Input_Bytes, Max_String_Len => 4096);

--  With custom nesting depth limit
R := Decoding.Decode_All (Input_Bytes, Max_Depth => 8);

--  Strict mode: reject trailing bytes
R := Decoding.Decode_All_Strict (Input_Bytes);

--  Manual nested decode (walk with Decode + Next)
R1 := Decoding.Decode (Data);
R2 := Decoding.Decode (Data, R1.Next);
```

## Well-formedness checks

The decoder rejects non-well-formed CBOR per RFC 8949:

- Additional information 28-30 (reserved)
- Simple values < 32 in two-byte form (Section 3.3)
- Non-shortest-form integer encoding
- String lengths exceeding `Stream_Element_Offset'Last`
- Truncated input (incomplete heads, strings, containers)
- Indefinite-length for major types 0, 1, 6
- Break outside indefinite-length containers
- Wrong chunk types in indefinite-length byte/text strings
- Odd item count in indefinite-length maps at break
- Nesting depth exceeding 16

## Error codes

| Status | Meaning |
|--------|---------|
| `OK` | Successful decode |
| `Err_Not_Well_Formed` | RFC 8949 well-formedness violation |
| `Err_Truncated` | Input cut short (incomplete item) |
| `Err_Trailing_Data` | Extra bytes after top-level item (strict mode) |
| `Err_Depth_Exceeded` | Nesting depth > `Max_Depth` (configurable, default 16) |
| `Err_Invalid_UTF8` | Invalid UTF-8 in text string (when `Check_UTF8 => True`) |
| `Err_Too_Many_Items` | Item tree exceeds `Max_Decode_Items` (128) |
| `Err_String_Too_Long` | String length exceeds `Max_String_Len` parameter |
| `Err_Resource_Limit` | Map count too large to represent as item pairs |

## SPARK proof status

| Component    | Proved | Notes |
|-------------|--------|-------|
| Encoder     | 100%   | Proved at Level 2 |
| Decoder     | 100%   | Proved at Level 1 and Level 2 |
| Properties  | Ghost  | Round-trip lemmas with postconditions |
| **Total**   | **100%** | **0 unproved checks** |

## Limitations

- Float values are encoded/decoded as opaque byte arrays (no IEEE 754 conversion)
- No half-precision float conversion utility
- UTF-8 validation is opt-in via `Check_UTF8` parameter
- `Encode_Text_String` serializes raw Character'Pos bytes (Latin-1); use `Encode_Text_String_UTF8` for pre-encoded UTF-8
- `Decode_All` returns at most 128 items (`Max_Decode_Items`)
- Tag semantics (e.g., tag 0 date validation) are not enforced
- `Decode_All` accepts trailing bytes; use `Decode_All_Strict` to reject them

## Dependencies

- GNAT >= 15.1 (Ada 2022)
- gnatprove >= 15.1 (for SPARK proofs only — not a library dependency)

## License

Apache-2.0. Certification artifacts, safety case documentation, and formal verification evidence packages available for safety-critical deployments — contact [baris@erdem.dev](mailto:baris@erdem.dev).
