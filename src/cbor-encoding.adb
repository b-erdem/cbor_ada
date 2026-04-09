with Interfaces;

package body CBOR.Encoding is

   pragma SPARK_Mode;

   use type Ada.Streams.Stream_Element;
   use Interfaces;

   package SE renames Ada.Streams;

   subtype U8 is Unsigned_8;
   subtype U64 is CBOR.UInt64;

   Max_Input : constant SE.Stream_Element_Offset :=
     SE.Stream_Element_Offset (Max_Data_Length);

   function Make_Head
     (MT  : CBOR.Major_Type;
      Val : U8)
      return SE.Stream_Element
   is
      MT_Bits : constant U8 :=
        Shift_Left (CBOR.MT_To_U8 (MT), 5);
   begin
      return SE.Stream_Element (MT_Bits or Val);
   end Make_Head;

   function To_SE (V : U8) return SE.Stream_Element
   is (SE.Stream_Element (V));

   function Encode_Head
     (MT  : CBOR.Major_Type;
      Val : U64)
      return SE.Stream_Element_Array
   is
      H : constant SE.Stream_Element :=
        Make_Head (MT, 0);
   begin
      if Val <= 23 then
         declare
            R : constant SE.Stream_Element_Array (1 .. 1) :=
              [1 => H + SE.Stream_Element (Val)];
         begin
            pragma Assert (R'Length = 1);
            pragma Assert (Head_Length (Val) = 1);
            return R;
         end;
      elsif Val <= 255 then
         declare
            R : constant SE.Stream_Element_Array (1 .. 2) :=
              [1 => H + 24,
               2 => To_SE (U8 (Val))];
         begin
            pragma Assert (R'Length = 2);
            pragma Assert (Head_Length (Val) = 2);
            return R;
         end;
      elsif Val <= 65535 then
         declare
            V : constant Unsigned_16 :=
              Unsigned_16 (Val);
            R : constant SE.Stream_Element_Array (1 .. 3) :=
              [1 => H + 25,
               2 => To_SE (U8 (Shift_Right (V, 8))),
               3 => To_SE (U8 (V and 16#FF#))];
         begin
            pragma Assert (R'Length = 3);
            pragma Assert (Head_Length (Val) = 3);
            return R;
         end;
      elsif Val <= 16#FFFF_FFFF# then
         declare
            V : constant Unsigned_32 :=
              Unsigned_32 (Val);
            R : constant SE.Stream_Element_Array (1 .. 5) :=
              [1 => H + 26,
               2 => To_SE (U8 (Shift_Right (V, 24))),
               3 => To_SE
                     (U8 (Shift_Right (V, 16) and 16#FF#)),
               4 => To_SE
                     (U8 (Shift_Right (V, 8) and 16#FF#)),
               5 => To_SE (U8 (V and 16#FF#))];
         begin
            pragma Assert (R'Length = 5);
            pragma Assert (Head_Length (Val) = 5);
            return R;
         end;
      else
         declare
            V : constant Unsigned_64 := Val;
            R : constant SE.Stream_Element_Array (1 .. 9) :=
              [1 => H + 27,
               2 => To_SE (U8 (Shift_Right (V, 56))),
               3 => To_SE
                     (U8 (Shift_Right (V, 48) and 16#FF#)),
               4 => To_SE
                     (U8 (Shift_Right (V, 40) and 16#FF#)),
               5 => To_SE
                     (U8 (Shift_Right (V, 32) and 16#FF#)),
               6 => To_SE
                     (U8 (Shift_Right (V, 24) and 16#FF#)),
               7 => To_SE
                     (U8 (Shift_Right (V, 16) and 16#FF#)),
               8 => To_SE
                     (U8 (Shift_Right (V, 8) and 16#FF#)),
               9 => To_SE (U8 (V and 16#FF#))];
         begin
            pragma Assert (R'Length = 9);
            pragma Assert (Head_Length (Val) = 9);
            return R;
         end;
      end if;
   end Encode_Head;

   procedure Append_All
     (Target : in out SE.Stream_Element_Array;
      Source : SE.Stream_Element_Array;
      From   : SE.Stream_Element_Offset)
   is
   begin
      for I in SE.Stream_Element_Offset range
        1 .. Source'Length
      loop
         pragma Loop_Invariant
           (I <= Source'Length);
         Target (From + I - 1) :=
           Source (Source'First + (I - 1));
      end loop;
   end Append_All;

   function Encode_Unsigned
     (Value : CBOR.UInt64)
      return SE.Stream_Element_Array
   is
   begin
      return Encode_Head (CBOR.MT_Unsigned_Integer, Value);
   end Encode_Unsigned;

   function Encode_Negative
     (Arg : CBOR.UInt64)
      return SE.Stream_Element_Array
   is
   begin
      return Encode_Head (CBOR.MT_Negative_Integer, Arg);
   end Encode_Negative;

   function Encode_Byte_String
     (Data : SE.Stream_Element_Array)
      return SE.Stream_Element_Array
   is
      Header : constant SE.Stream_Element_Array :=
        Encode_Head (CBOR.MT_Byte_String, U64 (Data'Length));
      HL : constant SE.Stream_Element_Offset :=
        Header'Length;
      DL : constant SE.Stream_Element_Offset :=
        Data'Length;
      R  : SE.Stream_Element_Array (1 .. HL + DL) :=
        [others => 0];
   begin
      Append_All (R, Header, 1);
      Append_All (R, Data, HL + 1);
      return R;
   end Encode_Byte_String;

   function Encode_Text_String
     (Text : String)
      return SE.Stream_Element_Array
   is
      Len : constant SE.Stream_Element_Offset :=
        Text'Length;
      Header : constant SE.Stream_Element_Array :=
        Encode_Head (CBOR.MT_Text_String, U64 (Len));
      HL : constant SE.Stream_Element_Offset :=
        Header'Length;
      R  : SE.Stream_Element_Array (1 .. HL + Len) :=
        [others => 0];
      Idx : SE.Stream_Element_Offset := HL + 1;
   begin
      Append_All (R, Header, 1);
      for C of Text loop
         pragma Loop_Invariant
           (Idx >= HL + 1
            and then Idx <= HL + Len + 1
            and then Len <= Max_Input);
         exit when Idx > HL + Len;
         R (Idx) :=
           SE.Stream_Element (Character'Pos (C));
         Idx := Idx + 1;
      end loop;
      return R;
   end Encode_Text_String;

   function Encode_Array
     (Count : CBOR.UInt64)
      return SE.Stream_Element_Array
   is
   begin
      return Encode_Head (CBOR.MT_Array, Count);
   end Encode_Array;

   function Encode_Map
     (Count : CBOR.UInt64)
      return SE.Stream_Element_Array
   is
   begin
      return Encode_Head (CBOR.MT_Map, Count);
   end Encode_Map;

   function Encode_Tag
     (Tag_Number : CBOR.UInt64)
      return SE.Stream_Element_Array
   is
   begin
      return Encode_Head (CBOR.MT_Tag, Tag_Number);
   end Encode_Tag;

   function Encode_Simple
     (Value : CBOR.UInt64)
      return SE.Stream_Element_Array
   is
      H : constant SE.Stream_Element :=
        Make_Head (CBOR.MT_Simple_Value, 0);
   begin
      if Value <= 23 then
         declare
            R : constant SE.Stream_Element_Array (1 .. 1) :=
              [1 => H + SE.Stream_Element (Value)];
         begin
            return R;
         end;
      else
         declare
            R : constant SE.Stream_Element_Array (1 .. 2) :=
              [1 => H + 24,
               2 => To_SE (U8 (Value))];
         begin
            return R;
         end;
      end if;
   end Encode_Simple;

   function Encode_Bool
     (Value : Boolean)
      return SE.Stream_Element_Array
   is
      R : constant SE.Stream_Element_Array (1 .. 1) :=
        [1 => (if Value then
                  Make_Head (CBOR.MT_Simple_Value, 0) + 21
               else
                  Make_Head (CBOR.MT_Simple_Value, 0) + 20)];
   begin
      return R;
   end Encode_Bool;

   function Encode_Null
      return SE.Stream_Element_Array
   is
      R : constant SE.Stream_Element_Array (1 .. 1) :=
        [1 => Make_Head (CBOR.MT_Simple_Value, 0) + 22];
   begin
      return R;
   end Encode_Null;

   function Encode_Undefined
      return SE.Stream_Element_Array
   is
      R : constant SE.Stream_Element_Array (1 .. 1) :=
        [1 => Make_Head (CBOR.MT_Simple_Value, 0) + 23];
   begin
      return R;
   end Encode_Undefined;

   function Encode_Float_Half
     (Bytes : SE.Stream_Element_Array)
      return SE.Stream_Element_Array
   is
      H : constant SE.Stream_Element_Array (1 .. 1) :=
        [1 => Make_Head (CBOR.MT_Simple_Value, 0) + 25];
      R  : SE.Stream_Element_Array (1 .. 3) :=
        [others => 0];
   begin
      R (1) := H (1);
      R (2) := Bytes (Bytes'First);
      R (3) := Bytes (Bytes'First + 1);
      return R;
   end Encode_Float_Half;

   function Encode_Float_Single
     (Bytes : SE.Stream_Element_Array)
      return SE.Stream_Element_Array
   is
      H : constant SE.Stream_Element_Array (1 .. 1) :=
        [1 => Make_Head (CBOR.MT_Simple_Value, 0) + 26];
      R  : SE.Stream_Element_Array (1 .. 5) :=
        [others => 0];
   begin
      R (1) := H (1);
      for I in SE.Stream_Element_Offset range
        1 .. 4
      loop
         pragma Loop_Invariant (I <= 4);
         R (1 + I) := Bytes
           (Bytes'First + SE.Stream_Element_Offset (I - 1));
      end loop;
      return R;
   end Encode_Float_Single;

   function Encode_Float_Double
     (Bytes : SE.Stream_Element_Array)
      return SE.Stream_Element_Array
   is
      H : constant SE.Stream_Element_Array (1 .. 1) :=
        [1 => Make_Head (CBOR.MT_Simple_Value, 0) + 27];
      R  : SE.Stream_Element_Array (1 .. 9) :=
        [others => 0];
   begin
      R (1) := H (1);
      for I in SE.Stream_Element_Offset range
        1 .. 8
      loop
         pragma Loop_Invariant (I <= 8);
         R (1 + I) := Bytes
           (Bytes'First + SE.Stream_Element_Offset (I - 1));
      end loop;
      return R;
   end Encode_Float_Double;

   function Encode_Break
      return SE.Stream_Element_Array
   is
      R : constant SE.Stream_Element_Array (1 .. 1) :=
        [1 => Make_Head (CBOR.MT_Simple_Value, 0) + 31];
   begin
      return R;
   end Encode_Break;

   function Encode_Array_Start
      return SE.Stream_Element_Array
   is
      R : constant SE.Stream_Element_Array (1 .. 1) :=
        [1 => Make_Head (CBOR.MT_Array, 31)];
   begin
      return R;
   end Encode_Array_Start;

   function Encode_Map_Start
      return SE.Stream_Element_Array
   is
      R : constant SE.Stream_Element_Array (1 .. 1) :=
        [1 => Make_Head (CBOR.MT_Map, 31)];
   begin
      return R;
   end Encode_Map_Start;

   function Encode_Byte_String_Start
      return SE.Stream_Element_Array
   is
      R : constant SE.Stream_Element_Array (1 .. 1) :=
        [1 => Make_Head (CBOR.MT_Byte_String, 31)];
   begin
      return R;
   end Encode_Byte_String_Start;

   function Encode_Text_String_Start
      return SE.Stream_Element_Array
   is
      R : constant SE.Stream_Element_Array (1 .. 1) :=
        [1 => Make_Head (CBOR.MT_Text_String, 31)];
   begin
      return R;
   end Encode_Text_String_Start;

end CBOR.Encoding;
