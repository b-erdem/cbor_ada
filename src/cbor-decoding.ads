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

   --  Decode a single CBOR data item starting at Pos.
   --  Pos = 0 means Data'First. Returns the decoded item and
   --  the offset of the last byte consumed.
   function Decode
     (Data  : Ada.Streams.Stream_Element_Array;
      Pos   : Ada.Streams.Stream_Element_Offset := 0)
      return Decode_Result
     with Pre => Pos = 0
                  or else Pos in Data'Range;

   --  Return the head size in bytes for a given additional info.
   function Head_Size
     (AI : Interfaces.Unsigned_8)
      return Ada.Streams.Stream_Element_Offset;

   --  Extract byte/text string content from Data using a String_Ref.
   --  Returns a new array with bounds 1 .. Ref.Length.
   function Get_String
     (Data : Ada.Streams.Stream_Element_Array;
      Ref  : String_Ref)
      return Ada.Streams.Stream_Element_Array
     with Pre => Ref.First in Data'Range
                 and then Ref.Length <= Data'Last - Ref.First + 1;

   --  Decode a complete CBOR data item tree with nested items.
   --  Uses an iterative stack (max depth = Max_Nesting_Depth).
   --  When Check_UTF8 is True, validates text string content
   --  as UTF-8 per RFC 3629 and returns Err_Invalid_UTF8 on failure.
   --  Returns Err_Too_Many_Items if the tree exceeds Max_Decode_Items.
   function Decode_All
     (Data       : Ada.Streams.Stream_Element_Array;
      Check_UTF8 : Boolean := False)
      return Decode_All_Result;

   --  Validate byte array as UTF-8 per RFC 3629.
   --  Rejects overlong encodings, surrogates (U+D800..U+DFFF),
   --  and code points above U+10FFFF.
   function Is_Valid_UTF8
     (Data : Ada.Streams.Stream_Element_Array)
      return Boolean;

end CBOR.Decoding;
