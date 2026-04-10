--  Copyright (C) 2025 Baris Erdem <baris@erdem.dev>
--  SPDX-License-Identifier: Apache-2.0

with Ada.Streams;
with Interfaces;

--  CBOR (RFC 8949) encoding/decoding library for Ada/SPARK.
--
--  This package provides core types for CBOR data items. The encoder
--  (CBOR.Encoding) is fully SPARK-proved (no runtime Errors possible).
--  The decoder (CBOR.Decoding) validates well-formedness per RFC 8949
--  including shortest-form checking, reserved AI rejection, string
--  length bounds, and nested depth limits.
--
--  Limitations:
--    - Float values are encoded/decoded as opaque byte arrays
--    - No half-precision float conversion (Layer 2)
--    - UTF-8 validation is optional (Check_UTF8 parameter)
--    - Decode_All limits items to Max_Decode_Items (128)
--    - Max nesting depth is Max_Nesting_Depth (16)

package CBOR is

   pragma Pure;
   pragma SPARK_Mode;

   package SE renames Ada.Streams;
   subtype Byte is SE.Stream_Element;
   subtype SE_Offset is SE.Stream_Element_Offset;
   subtype SE_Length is SE_Offset range 0 .. SE_Offset'Last;

   --  CBOR major types (RFC 8949 Section 3.1)
   type Major_Type is
     (MT_Unsigned_Integer,
      MT_Negative_Integer,
      MT_Byte_String,
      MT_Text_String,
      MT_Array,
      MT_Map,
      MT_Tag,
      MT_Simple_Value);

   --  SPARK-compatible conversion: Major_Type to its 3-bit encoding
   function MT_To_U8 (MT : Major_Type) return Interfaces.Unsigned_8 is
     (case MT is
         when MT_Unsigned_Integer => 0,
         when MT_Negative_Integer => 1,
         when MT_Byte_String     => 2,
         when MT_Text_String     => 3,
         when MT_Array           => 4,
         when MT_Map             => 5,
         when MT_Tag             => 6,
         when MT_Simple_Value    => 7);

   --  SPARK-compatible conversion: 3-bit encoding to Major_Type
   subtype MT_Encoding is Interfaces.Unsigned_8 range 0 .. 7;

   function U8_To_MT (Val : MT_Encoding) return Major_Type is
     (case Val is
         when 0 => MT_Unsigned_Integer,
         when 1 => MT_Negative_Integer,
         when 2 => MT_Byte_String,
         when 3 => MT_Text_String,
         when 4 => MT_Array,
         when 5 => MT_Map,
         when 6 => MT_Tag,
         when 7 => MT_Simple_Value);

   subtype UInt64 is Interfaces.Unsigned_64;

   --  RFC 8949 Section 3.3 simple value assignments
   Simple_False : constant := 20;
   Simple_True  : constant := 21;
   Simple_Null  : constant := 22;
   Simple_Undef : constant := 23;

   --  Reference into a source buffer for byte/text string content.
   --  Use CBOR.Decoding.Get_String to extract the actual bytes.
   type String_Ref is record
      First  : SE_Offset;
      Length : SE_Length;
   end record;

   Null_Ref : constant String_Ref :=
     (First => 1, Length => 0);

   --  Maximum nesting depth for Decode_All. Exceeding this
   --  returns Err_Depth_Exceeded.
   Max_Nesting_Depth : constant := 16;

   --  Decoded CBOR data item. Head_Start/Item_End give the
   --  byte range in the source buffer. Item_End is the last
   --  byte of the complete item (including string payload
   --  for byte/text strings). The variant fields
   --  depend on Kind:
   --    MT_Unsigned_Integer => UInt_Value (0 .. 2^64-1)
   --    MT_Negative_Integer => NInt_Arg (value is -1 - NInt_Arg)
   --    MT_Byte_String      => BS_Ref (use Get_String)
   --    MT_Text_String      => TS_Ref (use Get_String)
   --    MT_Array            => Arr_Count (UInt64'Last = indefinite)
   --    MT_Map              => Map_Count (UInt64'Last = indefinite)
   --    MT_Tag              => Tag_Number (0 .. 2^64-1)
   --    MT_Simple_Value     => SV_Value (0..23, 32..255)
   --                          Float_Ref for AI 25/26/27 (half/single/double)
   --                          SV_Value=31 means break (only from Decode_All)
   type CBOR_Item (Kind : Major_Type := MT_Unsigned_Integer) is record
      Head_Start : SE_Offset := 1;
      Item_End   : SE_Offset := 1;
      case Kind is
         when MT_Unsigned_Integer =>
            UInt_Value : UInt64 := 0;
         when MT_Negative_Integer =>
            NInt_Arg : UInt64 := 0;
         when MT_Byte_String =>
            BS_Ref : String_Ref := Null_Ref;
         when MT_Text_String =>
            TS_Ref : String_Ref := Null_Ref;
         when MT_Array =>
            Arr_Count : UInt64 := 0;
         when MT_Map =>
            Map_Count : UInt64 := 0;
         when MT_Tag =>
            Tag_Number : UInt64 := 0;
         when MT_Simple_Value =>
            SV_Value  : Interfaces.Unsigned_8 := 0;
            Float_Ref : String_Ref := Null_Ref;
      end case;
   end record;

   type Decode_Status is
     (OK,
      Err_Not_Well_Formed,
      Err_Truncated,
      Err_Trailing_Data,
      Err_Depth_Exceeded,
      Err_Invalid_UTF8,
      Err_Too_Many_Items,
      Err_String_Too_Long,
      Err_Resource_Limit);

   --  Result of single-item Decode. Next is the position of
   --  the first unconsumed byte (Data'Last + 1 when all input
   --  is consumed). On error, Item has default values.
   type Decode_Result is record
      Status : Decode_Status := OK;
      Item   : CBOR_Item;
      Next   : SE_Offset := 1;
   end record;

   Max_Decode_Items : constant := 128;

   type Item_Count is range 0 .. Max_Decode_Items;
   subtype Item_Range is Item_Count range 1 .. Max_Decode_Items;

   type Item_Array is array (Item_Range) of CBOR_Item;

   --  Result of Decode_All. Next is the position of the first
   --  unconsumed byte (Data'Last + 1 when all input is consumed).
   type Decode_All_Result is record
      Status : Decode_Status := OK;
      Items  : Item_Array;
      Count  : Item_Count := 0;
      Next   : SE_Offset := 1;
   end record;

end CBOR;
