--  Copyright (C) 2025 Baris Erdem <baris@erdem.dev>
--  SPDX-License-Identifier: AGPL-3.0-or-later
--
--  For commercial licensing terms, contact baris@erdem.dev.

--  SPARK-proved CBOR encoder (RFC 8949).
--  All functions produce well-formed, shortest-form CBOR.
--  The entire package is proved at SPARK Level 2 (no runtime errors).

package CBOR.Encoding is

   pragma SPARK_Mode;

   use type Ada.Streams.Stream_Element_Offset;
   use type CBOR.UInt64;

   --  Maximum input length to prevent overflow in result array sizing.
   Max_Data_Length : constant :=
     Ada.Streams.Stream_Element_Offset'Last / 2;

   --  Encode unsigned integer (major type 0, full 64-bit range).
   function Encode_Unsigned
     (Value : CBOR.UInt64)
      return Ada.Streams.Stream_Element_Array;

   --  Encode negative integer -1 - Arg (major type 1).
   function Encode_Negative
     (Arg : CBOR.UInt64)
      return Ada.Streams.Stream_Element_Array;

   --  Encode definite-length byte string (major type 2).
   function Encode_Byte_String
     (Data : Ada.Streams.Stream_Element_Array)
      return Ada.Streams.Stream_Element_Array
     with Pre => Data'Length <= Max_Data_Length;

   --  Encode definite-length text string (major type 3).
   --  Does NOT validate UTF-8; caller is responsible.
   function Encode_Text_String
     (Text : String)
      return Ada.Streams.Stream_Element_Array
     with Pre => Text'Length <= Max_Data_Length;

   --  Encode definite-length array header (major type 4).
   function Encode_Array
     (Count : CBOR.UInt64)
      return Ada.Streams.Stream_Element_Array;

   --  Encode definite-length map header (major type 5).
   function Encode_Map
     (Count : CBOR.UInt64)
      return Ada.Streams.Stream_Element_Array;

   --  Encode tag number (major type 6).
   function Encode_Tag
     (Tag_Number : CBOR.UInt64)
      return Ada.Streams.Stream_Element_Array;

   --  Encode simple value (major type 7, one or two bytes).
   --  Values 24-31 are reserved per RFC 8949 and rejected.
   function Encode_Simple
     (Value : CBOR.UInt64)
      return Ada.Streams.Stream_Element_Array
     with Pre => Value <= 255
                 and then (Value <= 23 or else Value >= 32);

   --  Encode boolean (simple values 20/21).
   function Encode_Bool
     (Value : Boolean)
      return Ada.Streams.Stream_Element_Array
     with Post => Encode_Bool'Result'Length = 1;

   --  Encode null (simple value 22).
   function Encode_Null
      return Ada.Streams.Stream_Element_Array
     with Post => Encode_Null'Result'Length = 1;

   --  Encode undefined (simple value 23).
   function Encode_Undefined
      return Ada.Streams.Stream_Element_Array
     with Post => Encode_Undefined'Result'Length = 1;

   --  Encode half-precision float (AI=25, raw 2 bytes).
   function Encode_Float_Half
     (Bytes : Ada.Streams.Stream_Element_Array)
      return Ada.Streams.Stream_Element_Array
     with Pre => Bytes'Length = 2;

   --  Encode single-precision float (AI=26, raw 4 bytes).
   function Encode_Float_Single
     (Bytes : Ada.Streams.Stream_Element_Array)
      return Ada.Streams.Stream_Element_Array
     with Pre => Bytes'Length = 4;

   --  Encode double-precision float (AI=27, raw 8 bytes).
   function Encode_Float_Double
     (Bytes : Ada.Streams.Stream_Element_Array)
      return Ada.Streams.Stream_Element_Array
     with Pre => Bytes'Length = 8;

   --  Encode break stop code (0xFF).
   function Encode_Break
      return Ada.Streams.Stream_Element_Array
     with Post => Encode_Break'Result'Length = 1;

   --  Start indefinite-length array (0x9F).
   function Encode_Array_Start
      return Ada.Streams.Stream_Element_Array
     with Post => Encode_Array_Start'Result'Length = 1;

   --  Start indefinite-length map (0xBF).
   function Encode_Map_Start
      return Ada.Streams.Stream_Element_Array
     with Post => Encode_Map_Start'Result'Length = 1;

   --  Start indefinite-length byte string (0x5F).
   function Encode_Byte_String_Start
      return Ada.Streams.Stream_Element_Array
     with Post => Encode_Byte_String_Start'Result'Length = 1;

   --  Start indefinite-length text string (0x7F).
   function Encode_Text_String_Start
      return Ada.Streams.Stream_Element_Array
     with Post => Encode_Text_String_Start'Result'Length = 1;

private

   function Head_Length
     (Val : CBOR.UInt64)
      return Ada.Streams.Stream_Element_Offset
   is
     (if Val <= 23 then 1
      elsif Val <= 255 then 2
      elsif Val <= 65535 then 3
      elsif Val <= 16#FFFF_FFFF# then 5
      else 9);

   function Encode_Head
     (MT  : CBOR.Major_Type;
      Val : CBOR.UInt64)
      return Ada.Streams.Stream_Element_Array
     with Post => Encode_Head'Result'Length = Head_Length (Val);

end CBOR.Encoding;
