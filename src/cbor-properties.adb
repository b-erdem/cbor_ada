--  Copyright (C) 2025 Baris Erdem <baris@erdem.dev>
--  SPDX-License-Identifier: Apache-2.0

package body CBOR.Properties is

   pragma SPARK_Mode;

   package Enc renames CBOR.Encoding;
   package Dec renames CBOR.Decoding;
   package SE renames Ada.Streams;

   use type SE.Stream_Element;
   use type SE.Stream_Element_Offset;

   procedure Lemma_Round_Trip_Unsigned (Value : CBOR.UInt64) is
      Encoded : constant SE.Stream_Element_Array :=
        Enc.Encode_Unsigned (Value);
      Result  : constant CBOR.Decode_Result :=
        Dec.Decode (Encoded);
   begin
      pragma Assert (Result.Status = CBOR.OK);
      pragma Assert (Result.Item.Kind = CBOR.MT_Unsigned_Integer);
      pragma Assert (Result.Item.UInt_Value = Value);
   end Lemma_Round_Trip_Unsigned;

   procedure Lemma_Round_Trip_Negative (Arg : CBOR.UInt64) is
      Encoded : constant SE.Stream_Element_Array :=
        Enc.Encode_Negative (Arg);
      Result  : constant CBOR.Decode_Result :=
        Dec.Decode (Encoded);
   begin
      pragma Assert (Result.Status = CBOR.OK);
      pragma Assert (Result.Item.Kind = CBOR.MT_Negative_Integer);
      pragma Assert (Result.Item.NInt_Arg = Arg);
   end Lemma_Round_Trip_Negative;

   procedure Lemma_Round_Trip_Bool (Value : Boolean) is
      Encoded : constant SE.Stream_Element_Array :=
        Enc.Encode_Bool (Value);
      Result  : constant CBOR.Decode_Result :=
        Dec.Decode (Encoded);
   begin
      pragma Assert (Result.Status = CBOR.OK);
      pragma Assert (Result.Item.Kind = CBOR.MT_Simple_Value);
      if Value then
         pragma Assert (Result.Item.SV_Value = 21);
      else
         pragma Assert (Result.Item.SV_Value = 20);
      end if;
   end Lemma_Round_Trip_Bool;

   procedure Lemma_Round_Trip_Null is
      Encoded : constant SE.Stream_Element_Array :=
        Enc.Encode_Null;
      Result  : constant CBOR.Decode_Result :=
        Dec.Decode (Encoded);
   begin
      pragma Assert (Result.Status = CBOR.OK);
      pragma Assert (Result.Item.Kind = CBOR.MT_Simple_Value);
      pragma Assert (Result.Item.SV_Value = 22);
   end Lemma_Round_Trip_Null;

   procedure Lemma_Round_Trip_Undefined is
      Encoded : constant SE.Stream_Element_Array :=
        Enc.Encode_Undefined;
      Result  : constant CBOR.Decode_Result :=
        Dec.Decode (Encoded);
   begin
      pragma Assert (Result.Status = CBOR.OK);
      pragma Assert (Result.Item.Kind = CBOR.MT_Simple_Value);
      pragma Assert (Result.Item.SV_Value = 23);
   end Lemma_Round_Trip_Undefined;

   procedure Lemma_Round_Trip_Simple (Value : CBOR.UInt64) is
      Encoded : constant SE.Stream_Element_Array :=
        Enc.Encode_Simple (Interfaces.Unsigned_8 (Value));
      Result  : constant CBOR.Decode_Result :=
        Dec.Decode (Encoded);
   begin
      pragma Assert (Result.Status = CBOR.OK);
      pragma Assert (Result.Item.Kind = CBOR.MT_Simple_Value);
      pragma Assert (CBOR.UInt64 (Result.Item.SV_Value) = Value);
   end Lemma_Round_Trip_Simple;

   procedure Lemma_Round_Trip_Tag (Tag_Number : CBOR.UInt64) is
      Encoded : constant SE.Stream_Element_Array :=
        Enc.Encode_Tag (Tag_Number);
      Result  : constant CBOR.Decode_Result :=
        Dec.Decode (Encoded);
   begin
      pragma Assert (Result.Status = CBOR.OK);
      pragma Assert (Result.Item.Kind = CBOR.MT_Tag);
      pragma Assert (Result.Item.Tag_Number = Tag_Number);
   end Lemma_Round_Trip_Tag;

   procedure Lemma_Round_Trip_Array (Count : CBOR.UInt64) is
      Encoded : constant SE.Stream_Element_Array :=
        Enc.Encode_Array (Count);
      Result  : constant CBOR.Decode_Result :=
        Dec.Decode (Encoded);
   begin
      pragma Assert (Result.Status = CBOR.OK);
      pragma Assert (Result.Item.Kind = CBOR.MT_Array);
      pragma Assert (Result.Item.Arr_Count = Count);
   end Lemma_Round_Trip_Array;

   procedure Lemma_Round_Trip_Map (Count : CBOR.UInt64) is
      Encoded : constant SE.Stream_Element_Array :=
        Enc.Encode_Map (Count);
      Result  : constant CBOR.Decode_Result :=
        Dec.Decode (Encoded);
   begin
      pragma Assert (Result.Status = CBOR.OK);
      pragma Assert (Result.Item.Kind = CBOR.MT_Map);
      pragma Assert (Result.Item.Map_Count = Count);
   end Lemma_Round_Trip_Map;

   procedure Lemma_Round_Trip_Float_Half
     (B1, B2 : SE.Stream_Element)
   is
      Raw     : constant SE.Stream_Element_Array :=
        [1 => B1, 2 => B2];
      Encoded : constant SE.Stream_Element_Array :=
        Enc.Encode_Float_Half (Raw);
      Result  : constant CBOR.Decode_Result :=
        Dec.Decode (Encoded);
      Decoded : constant SE.Stream_Element_Array :=
        Dec.Get_String (Encoded, Result.Item.Float_Ref);
   begin
      pragma Assert (Result.Status = CBOR.OK);
      pragma Assert (Result.Item.Kind = CBOR.MT_Simple_Value);
      pragma Assert (Result.Item.SV_Value = 25);
      pragma Assert (Result.Item.Float_Ref.Length = 2);
      pragma Assert (Decoded (1) = B1);
      pragma Assert (Decoded (2) = B2);
   end Lemma_Round_Trip_Float_Half;

   procedure Lemma_Round_Trip_Float_Single
     (B1, B2, B3, B4 : SE.Stream_Element)
   is
      Raw     : constant SE.Stream_Element_Array :=
        [1 => B1, 2 => B2, 3 => B3, 4 => B4];
      Encoded : constant SE.Stream_Element_Array :=
        Enc.Encode_Float_Single (Raw);
      Result  : constant CBOR.Decode_Result :=
        Dec.Decode (Encoded);
      Decoded : constant SE.Stream_Element_Array :=
        Dec.Get_String (Encoded, Result.Item.Float_Ref);
   begin
      pragma Assert (Result.Status = CBOR.OK);
      pragma Assert (Result.Item.Kind = CBOR.MT_Simple_Value);
      pragma Assert (Result.Item.SV_Value = 26);
      pragma Assert (Result.Item.Float_Ref.Length = 4);
      pragma Assert (Decoded (1) = B1);
      pragma Assert (Decoded (2) = B2);
      pragma Assert (Decoded (3) = B3);
      pragma Assert (Decoded (4) = B4);
   end Lemma_Round_Trip_Float_Single;

   procedure Lemma_Round_Trip_Float_Double
     (B1, B2, B3, B4, B5, B6, B7, B8 : SE.Stream_Element)
   is
      Raw     : constant SE.Stream_Element_Array :=
        [1 => B1, 2 => B2, 3 => B3, 4 => B4,
         5 => B5, 6 => B6, 7 => B7, 8 => B8];
      Encoded : constant SE.Stream_Element_Array :=
        Enc.Encode_Float_Double (Raw);
      Result  : constant CBOR.Decode_Result :=
        Dec.Decode (Encoded);
      Decoded : constant SE.Stream_Element_Array :=
        Dec.Get_String (Encoded, Result.Item.Float_Ref);
   begin
      pragma Assert (Result.Status = CBOR.OK);
      pragma Assert (Result.Item.Kind = CBOR.MT_Simple_Value);
      pragma Assert (Result.Item.SV_Value = 27);
      pragma Assert (Result.Item.Float_Ref.Length = 8);
      pragma Assert (Decoded (1) = B1);
      pragma Assert (Decoded (2) = B2);
      pragma Assert (Decoded (3) = B3);
      pragma Assert (Decoded (4) = B4);
      pragma Assert (Decoded (5) = B5);
      pragma Assert (Decoded (6) = B6);
      pragma Assert (Decoded (7) = B7);
      pragma Assert (Decoded (8) = B8);
   end Lemma_Round_Trip_Float_Double;

end CBOR.Properties;
