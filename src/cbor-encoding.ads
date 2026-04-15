--  Copyright (C) 2025 Baris Erdem <baris@erdem.dev>
--  SPDX-License-Identifier: Apache-2.0

--  SPARK-proved CBOR encoder (RFC 8949).
--  All functions produce well-formed, shortest-form CBOR.
--  The entire package is proved at SPARK Level 2 (no runtime errors).

with Interfaces;

package CBOR.Encoding is

   pragma SPARK_Mode;

   use type CBOR.SE_Offset;
   use type CBOR.UInt64;
   use type Interfaces.Unsigned_8;

   --  Maximum input length to prevent overflow in result array sizing.
   Max_Data_Length : constant :=
     CBOR.SE_Offset'Last / 2;

   --  Encode unsigned integer (major type 0, full 64-bit range).
   --  @satisfies REQ-CBOR-001
   --  @satisfies REQ-CBOR-010
   --  @satisfies REQ-CBOR-060
   function Encode_Unsigned
     (Value : CBOR.UInt64)
      return CBOR.Byte_Array
     with Post => Encode_Unsigned'Result'Length in 1 .. 9;

   --  Encode negative integer -1 - Arg (major type 1).
   --  @satisfies REQ-CBOR-002
   --  @satisfies REQ-CBOR-010
   function Encode_Negative
     (Arg : CBOR.UInt64)
      return CBOR.Byte_Array
     with Post => Encode_Negative'Result'Length in 1 .. 9;

   --  Encode a signed integer using the appropriate CBOR major type.
   --  Non-negative values use major type 0 (unsigned).
   --  Negative values use major type 1 (negative, encoding -1 - N).
   --  Covers the range -(2^63) .. +(2^64 - 1) via separate paths.
   --  @satisfies REQ-CBOR-003
   function Encode_Integer
     (Value : Interfaces.Integer_64)
      return CBOR.Byte_Array
     with Post => Encode_Integer'Result'Length in 1 .. 9;

   --  Encode definite-length byte string (major type 2).
   --  @satisfies REQ-CBOR-004
   function Encode_Byte_String
     (Data : CBOR.Byte_Array)
      return CBOR.Byte_Array
     with Pre => Data'Length <= Max_Data_Length;

   --  Encode definite-length text string (major type 3).
   --  WARNING: Serializes raw Character'Pos bytes (Latin-1).
   --  Characters above 127 produce INVALID UTF-8 under CBOR's
   --  major type 3 (RFC 8949 Section 3.1 requires UTF-8).
   --  For ASCII-only strings this is safe. For non-ASCII content,
   --  use Encode_Text_String_UTF8 with pre-encoded UTF-8 bytes.
   function Encode_Text_String
     (Text : String)
      return CBOR.Byte_Array
     with Pre => Text'Length <= Max_Data_Length;

   --  Encode definite-length text string from raw UTF-8 bytes
   --  (major type 3). Use this when you have pre-encoded UTF-8
   --  content as a Byte_Array. Unlike Encode_Text_String,
   --  this avoids the Latin-1/Character'Pos ambiguity.
   --  @satisfies REQ-CBOR-005
   function Encode_Text_String_UTF8
     (Data : CBOR.Byte_Array)
      return CBOR.Byte_Array
     with Pre => Data'Length <= Max_Data_Length;

   --  Encode definite-length array header (major type 4).
   --  @satisfies REQ-CBOR-006
   --  @satisfies REQ-CBOR-010
   function Encode_Array
     (Count : CBOR.UInt64)
      return CBOR.Byte_Array
     with Post => Encode_Array'Result'Length in 1 .. 9;

   --  Encode definite-length map header (major type 5).
   --  @satisfies REQ-CBOR-007
   function Encode_Map
     (Count : CBOR.UInt64)
      return CBOR.Byte_Array
     with Post => Encode_Map'Result'Length in 1 .. 9;

   --  Encode tag number (major type 6).
   --  @satisfies REQ-CBOR-008
   function Encode_Tag
     (Tag_Number : CBOR.UInt64)
      return CBOR.Byte_Array
     with Post => Encode_Tag'Result'Length in 1 .. 9;

   --  Encode simple value (major type 7, one or two bytes).
   --  Values 24-31 are reserved per RFC 8949 and rejected.
   --  @satisfies REQ-CBOR-009
   function Encode_Simple
     (Value : Interfaces.Unsigned_8)
      return CBOR.Byte_Array
     with Pre => Value <= 23 or else Value >= 32,
          Post => Encode_Simple'Result'Length in 1 .. 2;

   --  Encode boolean (simple values 20/21).
   function Encode_Bool
     (Value : Boolean)
      return CBOR.Byte_Array
     with Post => Encode_Bool'Result'Length = 1;

   --  Encode null (simple value 22).
   function Encode_Null
      return CBOR.Byte_Array
     with Post => Encode_Null'Result'Length = 1;

   --  Encode undefined (simple value 23).
   function Encode_Undefined
      return CBOR.Byte_Array
     with Post => Encode_Undefined'Result'Length = 1;

   --  Encode half-precision float (AI=25, raw 2 big-endian bytes).
   --  Bytes must be in network byte order (big-endian).
   function Encode_Float_Half
     (Bytes : CBOR.Byte_Array)
      return CBOR.Byte_Array
     with Pre  => Bytes'Length = 2,
          Post => Encode_Float_Half'Result'Length = 3;

   --  Encode single-precision float (AI=26, raw 4 big-endian bytes).
   --  Bytes must be in network byte order (big-endian).
   function Encode_Float_Single
     (Bytes : CBOR.Byte_Array)
      return CBOR.Byte_Array
     with Pre  => Bytes'Length = 4,
          Post => Encode_Float_Single'Result'Length = 5;

   --  Encode double-precision float (AI=27, raw 8 big-endian bytes).
   --  Bytes must be in network byte order (big-endian).
   function Encode_Float_Double
     (Bytes : CBOR.Byte_Array)
      return CBOR.Byte_Array
     with Pre  => Bytes'Length = 8,
          Post => Encode_Float_Double'Result'Length = 9;

   --  Encode break stop code (0xFF).
   function Encode_Break
      return CBOR.Byte_Array
     with Post => Encode_Break'Result'Length = 1;

   --  Start indefinite-length array (0x9F).
   function Encode_Array_Start
      return CBOR.Byte_Array
     with Post => Encode_Array_Start'Result'Length = 1;

   --  Start indefinite-length map (0xBF).
   function Encode_Map_Start
      return CBOR.Byte_Array
     with Post => Encode_Map_Start'Result'Length = 1;

   --  Start indefinite-length byte string (0x5F).
   function Encode_Byte_String_Start
      return CBOR.Byte_Array
     with Post => Encode_Byte_String_Start'Result'Length = 1;

   --  Start indefinite-length text string (0x7F).
   function Encode_Text_String_Start
      return CBOR.Byte_Array
     with Post => Encode_Text_String_Start'Result'Length = 1;

private

   function Head_Length
     (Val : CBOR.UInt64)
      return CBOR.SE_Offset
   is
     (if Val <= 23 then 1
      elsif Val <= 255 then 2
      elsif Val <= 65535 then 3
      elsif Val <= 16#FFFF_FFFF# then 5
      else 9);

   function Encode_Head
     (MT  : CBOR.Major_Type;
      Val : CBOR.UInt64)
      return CBOR.Byte_Array
     with Post => Encode_Head'Result'Length = Head_Length (Val);

end CBOR.Encoding;
