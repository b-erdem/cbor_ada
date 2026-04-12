--  Copyright (C) 2025 Baris Erdem <baris@erdem.dev>
--  SPDX-License-Identifier: Apache-2.0

--  SPARK ghost lemmas proving encode/decode round-trip properties.
--  Each lemma asserts that decoding an encoded value yields the
--  original value. These are proof-only procedures (ghost) and
--  have no runtime cost.

with Ada.Streams;
with Interfaces;
with CBOR.Encoding;
with CBOR.Decoding;

use type Interfaces.Unsigned_64;
use type Interfaces.Unsigned_8;
use type Ada.Streams.Stream_Element_Offset;

package CBOR.Properties is

   pragma SPARK_Mode;

   procedure Lemma_Round_Trip_Unsigned (Value : CBOR.UInt64)
     with Ghost,
          Post => (declare
                     R : constant CBOR.Decode_Result :=
                       CBOR.Decoding.Decode
                         (CBOR.Encoding.Encode_Unsigned (Value));
                   begin
                     R.Status = CBOR.OK
                     and then R.Item.Kind = CBOR.MT_Unsigned_Integer
                     and then R.Item.UInt_Value = Value);

   procedure Lemma_Round_Trip_Negative (Arg : CBOR.UInt64)
     with Ghost,
          Post => (declare
                     R : constant CBOR.Decode_Result :=
                       CBOR.Decoding.Decode
                         (CBOR.Encoding.Encode_Negative (Arg));
                   begin
                     R.Status = CBOR.OK
                     and then R.Item.Kind = CBOR.MT_Negative_Integer
                     and then R.Item.NInt_Arg = Arg);

   procedure Lemma_Round_Trip_Bool (Value : Boolean)
     with Ghost,
          Post => (declare
                     R : constant CBOR.Decode_Result :=
                       CBOR.Decoding.Decode
                         (CBOR.Encoding.Encode_Bool (Value));
                   begin
                     R.Status = CBOR.OK
                     and then R.Item.Kind = CBOR.MT_Simple_Value
                     and then (if Value then R.Item.SV_Value = 21
                               else R.Item.SV_Value = 20));

   procedure Lemma_Round_Trip_Null
     with Ghost,
          Post => (declare
                     R : constant CBOR.Decode_Result :=
                       CBOR.Decoding.Decode
                         (CBOR.Encoding.Encode_Null);
                   begin
                     R.Status = CBOR.OK
                     and then R.Item.Kind = CBOR.MT_Simple_Value
                     and then R.Item.SV_Value = 22);

   procedure Lemma_Round_Trip_Undefined
     with Ghost,
          Post => (declare
                     R : constant CBOR.Decode_Result :=
                       CBOR.Decoding.Decode
                         (CBOR.Encoding.Encode_Undefined);
                   begin
                     R.Status = CBOR.OK
                     and then R.Item.Kind = CBOR.MT_Simple_Value
                     and then R.Item.SV_Value = 23);

   procedure Lemma_Round_Trip_Simple (Value : CBOR.UInt64)
     with Ghost,
          Pre => Value <= 255
                 and then (Value <= 23 or else Value >= 32),
          Post => (declare
                     R : constant CBOR.Decode_Result :=
                       CBOR.Decoding.Decode
                         (CBOR.Encoding.Encode_Simple
                            (Interfaces.Unsigned_8 (Value)));
                   begin
                     R.Status = CBOR.OK
                     and then R.Item.Kind = CBOR.MT_Simple_Value
                     and then CBOR.UInt64 (R.Item.SV_Value) = Value);

   procedure Lemma_Round_Trip_Tag (Tag_Number : CBOR.UInt64)
     with Ghost,
          Post => (declare
                     R : constant CBOR.Decode_Result :=
                       CBOR.Decoding.Decode
                         (CBOR.Encoding.Encode_Tag (Tag_Number));
                   begin
                     R.Status = CBOR.OK
                     and then R.Item.Kind = CBOR.MT_Tag
                     and then R.Item.Tag_Number = Tag_Number);

   procedure Lemma_Round_Trip_Array (Count : CBOR.UInt64)
     with Ghost,
          Post => (declare
                     R : constant CBOR.Decode_Result :=
                       CBOR.Decoding.Decode
                         (CBOR.Encoding.Encode_Array (Count));
                   begin
                     R.Status = CBOR.OK
                     and then R.Item.Kind = CBOR.MT_Array
                     and then R.Item.Arr_Count = Count);

   procedure Lemma_Round_Trip_Map (Count : CBOR.UInt64)
     with Ghost,
          Post => (declare
                     R : constant CBOR.Decode_Result :=
                       CBOR.Decoding.Decode
                         (CBOR.Encoding.Encode_Map (Count));
                   begin
                     R.Status = CBOR.OK
                     and then R.Item.Kind = CBOR.MT_Map
                     and then R.Item.Map_Count = Count);

   procedure Lemma_Round_Trip_Float_Half
     (B1, B2 : Ada.Streams.Stream_Element)
     with Ghost,
          Post => (declare
                     R : constant CBOR.Decode_Result :=
                       CBOR.Decoding.Decode
                         (CBOR.Encoding.Encode_Float_Half ([B1, B2]));
                   begin
                     R.Status = CBOR.OK
                     and then R.Item.Kind = CBOR.MT_Simple_Value
                     and then R.Item.SV_Value = 25
                     and then R.Item.Float_Ref.Length = 2);

   procedure Lemma_Round_Trip_Float_Single
     (B1, B2, B3, B4 : Ada.Streams.Stream_Element)
     with Ghost,
          Post => (declare
                     R : constant CBOR.Decode_Result :=
                       CBOR.Decoding.Decode
                         (CBOR.Encoding.Encode_Float_Single
                            ([B1, B2, B3, B4]));
                   begin
                     R.Status = CBOR.OK
                     and then R.Item.Kind = CBOR.MT_Simple_Value
                     and then R.Item.SV_Value = 26
                     and then R.Item.Float_Ref.Length = 4);

   procedure Lemma_Round_Trip_Float_Double
     (B1, B2, B3, B4, B5, B6, B7, B8 : Ada.Streams.Stream_Element)
     with Ghost,
          Post => (declare
                     R : constant CBOR.Decode_Result :=
                       CBOR.Decoding.Decode
                         (CBOR.Encoding.Encode_Float_Double
                            ([B1, B2, B3, B4, B5, B6, B7, B8]));
                   begin
                     R.Status = CBOR.OK
                     and then R.Item.Kind = CBOR.MT_Simple_Value
                     and then R.Item.SV_Value = 27
                     and then R.Item.Float_Ref.Length = 8);

end CBOR.Properties;
