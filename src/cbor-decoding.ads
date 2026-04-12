--  Copyright (C) 2025 Baris Erdem <baris@erdem.dev>
--  SPDX-License-Identifier: Apache-2.0

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
--    - Maximum nesting depth enforced (configurable, default 16)

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

   --  Decode a single CBOR data item header starting at Data'First.
   --  For containers (arrays, maps, tags, indefinite-length strings),
   --  only the header is decoded — child items are NOT validated.
   --  Use Decode_All for full tree validation of untrusted input.
   --  Result.Next is the first unconsumed byte position
   --  (Data'Last + 1 when the entire buffer is consumed).
   --  Standalone break (0xFF) is rejected as Err_Not_Well_Formed.
   function Decode
     (Data : Ada.Streams.Stream_Element_Array)
      return Decode_Result
     with Pre => Data'First >= 0
                 and then Data'Last <= Max_Data_Length,
          Post => (if Decode'Result.Status = OK then
                      Decode'Result.Item.Head_Start
                        in Data'Range
                      and then Decode'Result.Item.Item_End
                        in Data'Range
                      and then Decode'Result.Next
                        >= Data'First
                      and then Decode'Result.Next
                        <= Data'Last + 1
                      and then Decode'Result.Item.Item_End
                        >= Decode'Result.Item.Head_Start
                      and then Valid_Item_Refs
                                 (Data, Decode'Result.Item));

   --  Decode a single CBOR data item header starting at Pos.
   --  Same semantics as Decode (Data) — header only, no child
   --  validation.  Pos must be a valid index in Data'Range.
   function Decode
     (Data : Ada.Streams.Stream_Element_Array;
      Pos  : Ada.Streams.Stream_Element_Offset)
      return Decode_Result
     with Pre => Data'First >= 0
                 and then Data'Last <= Max_Data_Length
                 and then Pos in Data'Range,
          Post => (if Decode'Result.Status = OK then
                      Decode'Result.Item.Head_Start
                        in Data'Range
                      and then Decode'Result.Item.Item_End
                        in Data'Range
                      and then Decode'Result.Next
                        >= Data'First
                      and then Decode'Result.Next
                        <= Data'Last + 1
                      and then Decode'Result.Item.Item_End
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
   --  Uses an iterative stack (max depth = Max_Depth, capped at
   --  Max_Nesting_Depth = 16).
   --  When Check_UTF8 is True (the default), validates text string
   --  content as UTF-8 per RFC 3629 and returns Err_Invalid_UTF8
   --  on failure. Set to False only when performance is critical
   --  and input is known to be valid.
   --  Returns Err_Too_Many_Items if the tree exceeds Max_Decode_Items.
   --  Max_String_Len limits byte/text string lengths; returns
   --  Err_String_Too_Long if exceeded (default: no limit).
   --  For indefinite-length strings, the cumulative chunk length
   --  is tracked and also checked against Max_String_Len.
   function Decode_All
     (Data           : Ada.Streams.Stream_Element_Array;
      Check_UTF8     : Boolean := True;
      Max_String_Len : Ada.Streams.Stream_Element_Offset :=
        Ada.Streams.Stream_Element_Offset'Last;
      Max_Depth      : Natural := Max_Nesting_Depth)
      return Decode_All_Result
      with Pre => Data'First >= 0
                  and then Data'Last <= Max_Data_Length
                  and then Max_String_Len >= 0
                  and then Max_Depth <= Max_Nesting_Depth,
           Post => Decode_All'Result.Count <= Max_Decode_Items
                   and then (if Decode_All'Result.Status = OK
                             then Decode_All'Result.Count >= 1);

   --  Like Decode_All but rejects trailing bytes after the top-level
   --  item. Returns Err_Trailing_Data if Next /= Data'Last + 1.
   function Decode_All_Strict
     (Data           : Ada.Streams.Stream_Element_Array;
      Check_UTF8     : Boolean := True;
      Max_String_Len : Ada.Streams.Stream_Element_Offset :=
        Ada.Streams.Stream_Element_Offset'Last;
      Max_Depth      : Natural := Max_Nesting_Depth)
      return Decode_All_Result
     with Pre => Data'First >= 0
                 and then Data'Last <= Max_Data_Length
                 and then Max_String_Len >= 0
                 and then Max_Depth <= Max_Nesting_Depth,
          Post => Decode_All_Strict'Result.Count <= Max_Decode_Items
                  and then (if Decode_All_Strict'Result.Status = OK
                            then Decode_All_Strict'Result.Count >= 1);

   --  Validate byte array as UTF-8 per RFC 3629.
   --  Rejects overlong encodings, surrogates (U+D800..U+DFFF),
   --  and code points above U+10FFFF.
   function Is_Valid_UTF8
     (Data : Ada.Streams.Stream_Element_Array)
      return Boolean
     with Pre => Data'First >= 0
                 and then Data'Last <= Max_Data_Length;

end CBOR.Decoding;
