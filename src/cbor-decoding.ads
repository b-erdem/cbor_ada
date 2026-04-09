--  Copyright (C) 2025 Baris Erdem <baris@erdem.dev>
--  SPDX-License-Identifier: AGPL-3.0-or-later
--
--  For commercial licensing terms, contact baris@erdem.dev.

--  CBOR decoder (RFC 8949) with well-formedness validation.
--
--  Well-formedness checks performed:
--    - Additional information 28-30 rejected (reserved)
--    - Simple values < 32 in two-byte form rejected (Section 3.3)
--    - Shortest-form encoding required for all integer arguments
--    - String length bounded to SE_Offset'Last (prevents overflow)
--    - Truncated input detected
--    - Indefinite-length for major types 0, 1, 6 rejected
--    - Break only valid inside indefinite-length containers
--    - Indefinite-length string chunks must match parent major type
--    - Indefinite-length maps must have even item count at break
--    - Maximum nesting depth enforced (Max_Nesting_Depth = 16)

package CBOR.Decoding is

   pragma SPARK_Mode;

   use type Ada.Streams.Stream_Element_Offset;

   Max_Data_Length : constant Ada.Streams.Stream_Element_Offset :=
     Ada.Streams.Stream_Element_Offset'Last / 2;

   --  True when Ref points to a valid slice within Data.
   function Valid_String_Ref
     (Data : Ada.Streams.Stream_Element_Array;
      Ref  : String_Ref)
      return Boolean
   is
     (Data'First >= 0
      and then Data'Last <= Max_Data_Length
      and then (if Ref.Length > 0 then
                   Ref.First >= Data'First
                   and then Ref.First <= Data'Last
                   and then Ref.Length <= Data'Last
                   and then Data'Last - Ref.First
                                >= Ref.Length - 1))
     with Ghost;

   --  True when all string-like refs in Item are valid for Data.
   function Valid_Item_Refs
     (Data : Ada.Streams.Stream_Element_Array;
      Item : CBOR_Item)
      return Boolean
   is
     (case Item.Kind is
         when MT_Text_String  => Valid_String_Ref (Data, Item.TS_Ref),
         when MT_Byte_String  => Valid_String_Ref (Data, Item.BS_Ref),
         when MT_Simple_Value => Valid_String_Ref (Data, Item.Float_Ref),
         when others          => True)
     with Ghost,
          Pre => Data'First >= 0 and then Data'Last <= Max_Data_Length;

   --  Decode a single CBOR data item starting at Pos.
   --  Pos = 0 means Data'First. Returns the decoded item and
   --  the offset of the last byte consumed. Standalone break
   --  (0xFF) is rejected as Err_Not_Well_Formed; use Decode_All
   --  for parsing indefinite-length containers.
   function Decode
     (Data  : Ada.Streams.Stream_Element_Array;
      Pos   : Ada.Streams.Stream_Element_Offset := 0)
      return Decode_Result
     with Pre => Data'First >= 0
                 and then Data'Last <= Max_Data_Length
                 and then (Pos = 0
                           or else Pos in Data'Range),
          Post => (if Decode'Result.Status = OK then
                      Decode'Result.Item.Head_Start
                        in Data'Range
                      and then Decode'Result.Item.Head_End
                        in Data'Range
                      and then Decode'Result.Offset
                        in Data'Range
                      and then Decode'Result.Item.Head_End
                        >= Decode'Result.Item.Head_Start
                      and then Valid_Item_Refs
                                 (Data, Decode'Result.Item));

   --  Return the head size in bytes for a given additional info.
   function Head_Size
     (AI : Interfaces.Unsigned_8)
      return Ada.Streams.Stream_Element_Offset
     with Post => Head_Size'Result in 1 | 2 | 3 | 5 | 9;

   --  Extract byte/text string content from Data using a String_Ref.
   --  Returns a new array with bounds 1 .. Ref.Length (empty if Length = 0).
   function Get_String
     (Data : Ada.Streams.Stream_Element_Array;
      Ref  : String_Ref)
      return Ada.Streams.Stream_Element_Array
      with Pre => Valid_String_Ref (Data, Ref),
           Post => Get_String'Result'First = 1
                   and then Get_String'Result'Length = Ref.Length
                   and then Get_String'Result'Last = Ref.Length;

   --  Decode a complete CBOR data item tree with nested items.
   --  Uses an iterative stack (max depth = Max_Nesting_Depth).
   --  When Check_UTF8 is True, validates text string content
   --  as UTF-8 per RFC 3629 and returns Err_Invalid_UTF8 on failure.
   --  Returns Err_Too_Many_Items if the tree exceeds Max_Decode_Items.
   function Decode_All
     (Data       : Ada.Streams.Stream_Element_Array;
      Check_UTF8 : Boolean := False)
      return Decode_All_Result
      with Pre => Data'First >= 0
                  and then Data'Last <= Max_Data_Length;

   --  Like Decode_All but rejects trailing bytes after the top-level
   --  item. Returns Err_Truncated if Last_Pos /= Data'Last.
   function Decode_All_Strict
     (Data       : Ada.Streams.Stream_Element_Array;
      Check_UTF8 : Boolean := False)
      return Decode_All_Result
     with Pre => Data'First >= 0
                 and then Data'Last <= Max_Data_Length;

   --  Validate byte array as UTF-8 per RFC 3629.
   --  Rejects overlong encodings, surrogates (U+D800..U+DFFF),
   --  and code points above U+10FFFF.
   function Is_Valid_UTF8
     (Data : Ada.Streams.Stream_Element_Array)
      return Boolean
     with Pre => Data'First >= 0
                 and then Data'Last <= Max_Data_Length;

end CBOR.Decoding;
