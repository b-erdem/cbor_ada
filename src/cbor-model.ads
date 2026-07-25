--  Copyright (C) 2025 Baris Erdem <brserdem@proton.me>
--  SPDX-License-Identifier: Apache-2.0

--  Shared ghost specification (denotation) of a CBOR data-item head
--  (RFC 8949 Section 3). Both CBOR.Encoding and CBOR.Decoding are
--  specified against these functions, so encode/decode round-trip
--  lemmas in CBOR.Properties compose by contract:
--    - encoders guarantee   Well_Formed_Head (Result, 1)
--                           and Head_Value (Result, 1) = V
--    - the decoder guarantees success on any well-formed head
--      (completeness) and that the decoded item equals the head's
--      denotation (soundness).
--  All functions are total over their preconditions and are pure
--  expression functions, so they unfold at proof time.

with Interfaces;

package CBOR.Model with
  SPARK_Mode,
  Ghost
is

   use type Interfaces.Unsigned_8;
   use type CBOR.SE_Offset;
   use type CBOR.UInt64;

   --  Same bound as CBOR.Decoding.Max_Data_Length /
   --  CBOR.Encoding.Max_Data_Length.
   Max_Model_Length : constant CBOR.SE_Offset :=
     CBOR.SE_Offset'Last / 2;

   --  Additional-information bits (low 5) of the head byte at P.
   function Head_AI
     (Data : CBOR.Byte_Array;
      P    : CBOR.SE_Offset)
      return Interfaces.Unsigned_8
   is
     (Interfaces.Unsigned_8 (Data (P)) and 16#1F#)
     with Pre => P in Data'Range;

   --  Major type (high 3 bits) of the head byte at P.
   function Head_MT
     (Data : CBOR.Byte_Array;
      P    : CBOR.SE_Offset)
      return CBOR.Major_Type
   is
     (CBOR.U8_To_MT
        (Interfaces.Shift_Right (Interfaces.Unsigned_8 (Data (P)), 5)))
     with Pre => P in Data'Range;

   --  Head size in bytes implied by the additional information.
   function Head_Size
     (AI : Interfaces.Unsigned_8)
      return CBOR.SE_Offset
   is
     (case AI is
         when 0 .. 23 => 1,
         when 24      => 2,
         when 25      => 3,
         when 26      => 5,
         when 27      => 9,
         when others  => 1);

   --  All bytes of the head starting at P are inside Data.
   function Head_Bytes_Available
     (Data : CBOR.Byte_Array;
      P    : CBOR.SE_Offset)
      return Boolean
   is
     (Data'Last - P >= Head_Size (Head_AI (Data, P)) - 1)
     with Pre => Data'First >= 0
                 and then Data'Last <= Max_Model_Length
                 and then P in Data'Range;

   --  Big-endian value of the head's argument (the AI itself for
   --  AI <= 23, else the 1/2/4/8 following bytes).
   function Head_Value
     (Data : CBOR.Byte_Array;
      P    : CBOR.SE_Offset)
      return CBOR.UInt64
   is
     (case Head_AI (Data, P) is
         when 0 .. 23 =>
            CBOR.UInt64 (Head_AI (Data, P)),
         when 24 =>
            CBOR.UInt64 (Interfaces.Unsigned_8 (Data (P + 1))),
         when 25 =>
            CBOR.UInt64 (Interfaces.Unsigned_8 (Data (P + 1))) * 256
              + CBOR.UInt64 (Interfaces.Unsigned_8 (Data (P + 2))),
         when 26 =>
            CBOR.UInt64 (Interfaces.Unsigned_8 (Data (P + 1)))
                * 16#100_0000#
              + CBOR.UInt64 (Interfaces.Unsigned_8 (Data (P + 2)))
                  * 16#10000#
              + CBOR.UInt64 (Interfaces.Unsigned_8 (Data (P + 3)))
                  * 16#100#
              + CBOR.UInt64 (Interfaces.Unsigned_8 (Data (P + 4))),
         when 27 =>
            CBOR.UInt64 (Interfaces.Unsigned_8 (Data (P + 1)))
                * 16#100_0000_0000_0000#
              + CBOR.UInt64 (Interfaces.Unsigned_8 (Data (P + 2)))
                  * 16#100_0000_0000_00#
              + CBOR.UInt64 (Interfaces.Unsigned_8 (Data (P + 3)))
                  * 16#100_0000_0000#
              + CBOR.UInt64 (Interfaces.Unsigned_8 (Data (P + 4)))
                  * 16#100_0000_00#
              + CBOR.UInt64 (Interfaces.Unsigned_8 (Data (P + 5)))
                  * 16#100_0000#
              + CBOR.UInt64 (Interfaces.Unsigned_8 (Data (P + 6)))
                  * 16#10000#
              + CBOR.UInt64 (Interfaces.Unsigned_8 (Data (P + 7)))
                  * 16#100#
              + CBOR.UInt64 (Interfaces.Unsigned_8 (Data (P + 8))),
         when others =>
            0)
     with Pre => Data'First >= 0
                 and then Data'Last <= Max_Model_Length
                 and then P in Data'Range
                 and then Head_Bytes_Available (Data, P);

   --  Shortest-form (deterministic-encoding) requirement of
   --  RFC 8949 Section 4.2.1 for a head with additional info AI
   --  carrying argument Val.
   function Arg_Shortest
     (AI  : Interfaces.Unsigned_8;
      Val : CBOR.UInt64)
      return Boolean
   is
     (case AI is
         when 0 .. 23 => Val <= 23,
         when 24      => Val in 24 .. 255,
         when 25      => Val in 256 .. 65535,
         when 26      => Val in 65536 .. 16#FFFF_FFFF#,
         when 27      => Val >= 16#1_0000_0000#,
         when others  => True);

   --  A complete, well-formed, shortest-form, definite-length data
   --  item head at P (with full string payload present for major
   --  types 2 and 3). This is exactly the input class on which
   --  CBOR.Decoding.Decode is proved to succeed.
   function Well_Formed_Head
     (Data : CBOR.Byte_Array;
      P    : CBOR.SE_Offset)
      return Boolean
   is
     (P in Data'Range
      and then Head_AI (Data, P) <= 27
      and then Head_Bytes_Available (Data, P)
      and then
        (case Head_MT (Data, P) is
            when MT_Unsigned_Integer
               | MT_Negative_Integer
               | MT_Array
               | MT_Map
               | MT_Tag =>
               Arg_Shortest (Head_AI (Data, P), Head_Value (Data, P)),
            when MT_Byte_String
               | MT_Text_String =>
               Arg_Shortest (Head_AI (Data, P), Head_Value (Data, P))
               and then Head_Value (Data, P)
                          <= CBOR.UInt64 (CBOR.SE_Offset'Last)
               and then
                 (Head_Value (Data, P) = 0
                  or else
                    Data'Last
                      - (P + Head_Size (Head_AI (Data, P)) - 1)
                      >= CBOR.SE_Offset (Head_Value (Data, P))),
            when MT_Simple_Value =>
               (if Head_AI (Data, P) = 24
                then Interfaces.Unsigned_8 (Data (P + 1)) >= 32)))
     with Pre => Data'First >= 0
                 and then Data'Last <= Max_Model_Length;

end CBOR.Model;
