--  Copyright (C) 2025 Baris Erdem <baris@erdem.dev>
--  SPDX-License-Identifier: Apache-2.0

--  SPARK ghost lemmas proving encode/decode round-trip properties.
--  Each lemma asserts that decoding an encoded value yields the
--  original value. These are proof-only procedures (ghost) and
--  have no runtime cost.

with Ada.Streams;
with Interfaces;

use type Interfaces.Unsigned_64;

package CBOR.Properties is

   pragma SPARK_Mode;

   procedure Lemma_Round_Trip_Unsigned (Value : CBOR.UInt64)
     with Ghost;

   procedure Lemma_Round_Trip_Negative (Arg : CBOR.UInt64)
     with Ghost;

   procedure Lemma_Round_Trip_Bool (Value : Boolean)
     with Ghost;

   procedure Lemma_Round_Trip_Null with Ghost;

   procedure Lemma_Round_Trip_Undefined with Ghost;

   procedure Lemma_Round_Trip_Simple (Value : CBOR.UInt64)
     with Ghost,
          Pre => Value <= 255
                 and then (Value <= 23 or else Value >= 32);

   procedure Lemma_Round_Trip_Tag (Tag_Number : CBOR.UInt64)
     with Ghost;

   procedure Lemma_Round_Trip_Array (Count : CBOR.UInt64)
     with Ghost;

   procedure Lemma_Round_Trip_Map (Count : CBOR.UInt64)
     with Ghost;

   procedure Lemma_Round_Trip_Float_Half
     (B1, B2 : Ada.Streams.Stream_Element)
     with Ghost;

   procedure Lemma_Round_Trip_Float_Single
     (B1, B2, B3, B4 : Ada.Streams.Stream_Element)
     with Ghost;

   procedure Lemma_Round_Trip_Float_Double
     (B1, B2, B3, B4, B5, B6, B7, B8 : Ada.Streams.Stream_Element)
     with Ghost;

end CBOR.Properties;
