with CBOR;
with CBOR.Encoding;
with CBOR.Decoding;
with Ada.Streams;
with Ada.Numerics.Discrete_Random;
with Ada.Text_IO;
with GNAT.OS_Lib;
with Interfaces;

procedure Test_Cbor is

   use type Ada.Streams.Stream_Element;
   use type Ada.Streams.Stream_Element_Array;
   use type Ada.Streams.Stream_Element_Offset;
   use CBOR;
   use type CBOR.UInt64;
   use Interfaces;
   use Ada.Streams;

   package Enc renames CBOR.Encoding;
   package Dec renames CBOR.Decoding;
   package TIO renames Ada.Text_IO;

   Passes : Natural := 0;
   Fails  : Natural := 0;

   procedure Check_Kind
     (Name     : String;
      Expected : CBOR.Major_Type;
      Actual   : CBOR.Major_Type)
   is
   begin
      if Expected = Actual then
         Passes := Passes + 1;
      else
         Fails := Fails + 1;
         TIO.Put_Line
           ("FAIL: " & Name
            & " expected=" & Expected'Image
            & " got=" & Actual'Image);
      end if;
   end Check_Kind;

   procedure Check
     (Name     : String;
      Expected : UInt64;
      Actual   : UInt64)
   is
   begin
      if Expected = Actual then
         Passes := Passes + 1;
      else
         Fails := Fails + 1;
         TIO.Put_Line
           ("FAIL: " & Name
            & " expected=" & Expected'Image
            & " got=" & Actual'Image);
      end if;
   end Check;

   procedure Check_Status
     (Name     : String;
      Expected : CBOR.Decode_Status;
      Actual   : CBOR.Decode_Status)
   is
   begin
      if Expected = Actual then
         Passes := Passes + 1;
      else
         Fails := Fails + 1;
         TIO.Put_Line
           ("FAIL: " & Name
            & " expected=" & Expected'Image
            & " got=" & Actual'Image);
      end if;
   end Check_Status;

   procedure Check_Enc
     (Name     : String;
      Expected : Stream_Element_Array;
      Actual   : Stream_Element_Array)
   is
   begin
      if Expected'Length /= Actual'Length then
         Fails := Fails + 1;
         TIO.Put_Line
           ("FAIL: " & Name
            & " length mismatch expected="
            & Expected'Length'Image
            & " got=" & Actual'Length'Image);
         return;
      end if;
      for I in Stream_Element_Offset range
        0 .. Expected'Length - 1
      loop
         if Expected (Expected'First + I) /=
            Actual (Actual'First + I)
         then
            Fails := Fails + 1;
            TIO.Put_Line
              ("FAIL: " & Name
               & " byte mismatch at index"
               & I'Image);
            return;
         end if;
      end loop;
      Passes := Passes + 1;
   end Check_Enc;

   procedure Test_RFC8949_Encoding is
   begin
      TIO.Put_Line ("  RFC 8949 encoding vectors:");
      Check_Enc ("0", [16#00#],
                 Enc.Encode_Unsigned (0));
      Check_Enc ("1", [16#01#],
                 Enc.Encode_Unsigned (1));
      Check_Enc ("10", [16#0a#],
                 Enc.Encode_Unsigned (10));
      Check_Enc ("23", [16#17#],
                 Enc.Encode_Unsigned (23));
      Check_Enc ("24", [16#18#, 16#18#],
                 Enc.Encode_Unsigned (24));
      Check_Enc ("100", [16#18#, 16#64#],
                 Enc.Encode_Unsigned (100));
      Check_Enc ("1000",
                 [16#19#, 16#03#, 16#e8#],
                 Enc.Encode_Unsigned (1000));
      Check_Enc ("1000000",
                 [16#1a#, 16#00#, 16#0f#, 16#42#, 16#40#],
                 Enc.Encode_Unsigned (1_000_000));
      Check_Enc ("2^32",
                 [16#1a#, 16#ff#, 16#ff#, 16#ff#, 16#ff#],
                 Enc.Encode_Unsigned (16#FFFF_FFFF#));
      Check_Enc ("2^32+1",
                 [16#1b#, 16#00#, 16#00#, 16#00#,
                  16#01#, 16#00#, 16#00#, 16#00#, 16#00#],
                 Enc.Encode_Unsigned (16#1_0000_0000#));
      Check_Enc ("max u64",
                 [16#1b#, 16#ff#, 16#ff#, 16#ff#, 16#ff#,
                  16#ff#, 16#ff#, 16#ff#, 16#ff#],
                 Enc.Encode_Unsigned (UInt64'Last));
      Check_Enc ("-1", [16#20#],
                 Enc.Encode_Negative (0));
      Check_Enc ("-10", [16#29#],
                 Enc.Encode_Negative (9));
      Check_Enc ("-100",
                 [16#38#, 16#63#],
                 Enc.Encode_Negative (99));
      Check_Enc ("-1000",
                 [16#39#, 16#03#, 16#e7#],
                 Enc.Encode_Negative (999));
      Check_Enc ("false", [16#f4#],
                 Enc.Encode_Bool (False));
      Check_Enc ("true", [16#f5#],
                 Enc.Encode_Bool (True));
      Check_Enc ("null", [16#f6#],
                 Enc.Encode_Null);
      Check_Enc ("undefined", [16#f7#],
                 Enc.Encode_Undefined);
      Check_Enc ("empty text", [16#60#],
                 Enc.Encode_Text_String (""));
      Check_Enc ("text 'a'",
                 [16#61#, 16#61#],
                 Enc.Encode_Text_String ("a"));
      Check_Enc ("text 'IETF'",
                 [16#64#, 16#49#, 16#45#, 16#54#, 16#46#],
                 Enc.Encode_Text_String ("IETF"));
      Check_Enc ("[]", [16#80#],
                 Enc.Encode_Array (0));
      Check_Enc ("[1,2,3]", [16#83#],
                 Enc.Encode_Array (3));
      Check_Enc ("{}", [16#a0#],
                 Enc.Encode_Map (0));
      Check_Enc ("tag 0",
                 [16#c0#],
                 Enc.Encode_Tag (0));
      Check_Enc ("tag 1",
                 [16#c1#],
                 Enc.Encode_Tag (1));
   end Test_RFC8949_Encoding;

   procedure Test_Decode_Strings is
      E  : constant Stream_Element_Array :=
        Enc.Encode_Text_String ("hello");
      R  : constant CBOR.Decode_Result :=
        Dec.Decode (E);
      S  : constant Stream_Element_Array :=
        Dec.Get_String (E, R.Item.TS_Ref);
   begin
      TIO.Put_Line ("  String decode:");
      Check_Status ("text status", CBOR.OK, R.Status);
      Check_Kind ("text kind",
                  CBOR.MT_Text_String, R.Item.Kind);
      Check ("text len", 5,
             UInt64 (R.Item.TS_Ref.Length));
      Check ("text byte1", 104, UInt64 (S (1)));
      Check ("text byte5", 111, UInt64 (S (5)));
   end Test_Decode_Strings;

   procedure Test_Decode_Byte_String is
      Raw : constant Stream_Element_Array :=
        [16#de#, 16#ad#, 16#be#, 16#ef#];
      E   : constant Stream_Element_Array :=
        Enc.Encode_Byte_String (Raw);
      R   : constant CBOR.Decode_Result :=
        Dec.Decode (E);
      S   : constant Stream_Element_Array :=
        Dec.Get_String (E, R.Item.BS_Ref);
   begin
      TIO.Put_Line ("  Byte string decode:");
      Check_Status ("bs status", CBOR.OK, R.Status);
      Check ("bs len", 4,
             UInt64 (R.Item.BS_Ref.Length));
      Check ("bs byte1", 16#de#, UInt64 (S (1)));
      Check ("bs byte4", 16#ef#, UInt64 (S (4)));
   end Test_Decode_Byte_String;

   procedure Test_Decode_Nested is
      E : constant Stream_Element_Array :=
        Enc.Encode_Array (2)
        & Enc.Encode_Unsigned (1)
        & Enc.Encode_Bool (True);
      R1 : constant CBOR.Decode_Result := Dec.Decode (E);
      R2 : CBOR.Decode_Result;
      R3 : CBOR.Decode_Result;
   begin
      TIO.Put_Line ("  Nested decode:");
      Check_Status ("arr status", CBOR.OK, R1.Status);
      Check_Kind ("arr kind",
                  CBOR.MT_Array, R1.Item.Kind);
      Check ("arr count", 2, R1.Item.Arr_Count);
      R2 := Dec.Decode (E, R1.Offset + 1);
      Check_Status ("elem1 status", CBOR.OK, R2.Status);
      Check ("elem1 value", 1, R2.Item.UInt_Value);
      R3 := Dec.Decode (E, R2.Offset + 1);
      Check_Status ("elem2 status", CBOR.OK, R3.Status);
      Check ("elem2 sv", 21,
             UInt64 (R3.Item.SV_Value));
   end Test_Decode_Nested;

   procedure Test_Well_Formedness is
      Bad1 : constant Stream_Element_Array := [16#1c#];
      R1   : constant CBOR.Decode_Result :=
        Dec.Decode (Bad1);
      Bad2 : constant Stream_Element_Array :=
        [16#f8#, 16#10#];
      R2   : constant CBOR.Decode_Result :=
        Dec.Decode (Bad2);
      Trunc : constant Stream_Element_Array := [16#19#];
      R3    : constant CBOR.Decode_Result :=
        Dec.Decode (Trunc);
   begin
      TIO.Put_Line ("  Well-formedness:");
      Check_Status ("AI=28 rejected",
             CBOR.Err_Not_Well_Formed, R1.Status);
      Check_Status ("simple<32 rejected",
             CBOR.Err_Not_Well_Formed, R2.Status);
      Check_Status ("truncated rejected",
             CBOR.Err_Truncated, R3.Status);
   end Test_Well_Formedness;

   procedure Test_New_Features is
      R_Undef : CBOR.Decode_Result;
      R_Simple : CBOR.Decode_Result;
      R_Float : CBOR.Decode_Result;
      R_Break : CBOR.Decode_Result;
      R_ArrSt : CBOR.Decode_Result;
   begin
      TIO.Put_Line ("  New features:");
      R_Undef := Dec.Decode (Enc.Encode_Undefined);
      Check ("undef sv", 23,
             UInt64 (R_Undef.Item.SV_Value));

      R_Simple := Dec.Decode (Enc.Encode_Simple (32));
      Check ("simple32 sv", 32,
             UInt64 (R_Simple.Item.SV_Value));

      declare
         Float_Bytes : constant Stream_Element_Array :=
           [16#3c#, 16#00#];
      begin
         R_Float := Dec.Decode
           (Enc.Encode_Float_Half (Float_Bytes));
         Check_Status ("float_half status", CBOR.OK,
                R_Float.Status);
      end;

      R_Break := Dec.Decode (Enc.Encode_Break);
      Check_Status ("break rejected",
                    CBOR.Err_Not_Well_Formed, R_Break.Status);

      R_ArrSt := Dec.Decode (Enc.Encode_Array_Start);
      Check ("arr_start count",
             UInt64'Last, R_ArrSt.Item.Arr_Count);
   end Test_New_Features;

   procedure Test_Decode_Raw is
      R1 : constant CBOR.Decode_Result :=
        Dec.Decode ([16#00#]);
      R2 : constant CBOR.Decode_Result :=
        Dec.Decode ([16#18#, 16#18#]);
      R3 : constant CBOR.Decode_Result :=
        Dec.Decode ([16#19#, 16#01#, 16#00#]);
   begin
      TIO.Put_Line ("  Raw decode:");
      Check_Status ("dec 0", CBOR.OK, R1.Status);
      Check ("dec 0 val", 0, R1.Item.UInt_Value);
      Check_Status ("dec 24", CBOR.OK, R2.Status);
      Check ("dec 24 val", 24, R2.Item.UInt_Value);
      Check_Status ("dec 256", CBOR.OK, R3.Status);
      Check ("dec 256 val", 256, R3.Item.UInt_Value);
   end Test_Decode_Raw;

   procedure Test_Decode_All_Basic is
      E : constant Stream_Element_Array :=
        Enc.Encode_Array (2)
        & Enc.Encode_Unsigned (1)
        & Enc.Encode_Bool (True);
      R : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (E);
   begin
      TIO.Put_Line ("  Decode_All basic:");
      Check_Status ("all status", CBOR.OK, R.Status);
      Check ("all count", 3, UInt64 (R.Count));
      Check_Kind ("all[0]",
                  CBOR.MT_Array, R.Items (1).Kind);
      Check ("all[0] cnt", 2, R.Items (1).Arr_Count);
      Check_Kind ("all[1]",
                  CBOR.MT_Unsigned_Integer,
                  R.Items (2).Kind);
      Check ("all[1] val", 1, R.Items (2).UInt_Value);
      Check_Kind ("all[2]",
                  CBOR.MT_Simple_Value,
                  R.Items (3).Kind);
      Check ("all[2] sv", 21,
             UInt64 (R.Items (3).SV_Value));
   end Test_Decode_All_Basic;

   procedure Test_Decode_All_Nested is
      E : constant Stream_Element_Array :=
        Enc.Encode_Array (2)
        & Enc.Encode_Array (1)
        & Enc.Encode_Unsigned (42)
        & Enc.Encode_Bool (False);
      R : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (E);
   begin
      TIO.Put_Line ("  Decode_All nested:");
      Check_Status ("nested status", CBOR.OK, R.Status);
      Check ("nested count", 4, UInt64 (R.Count));
      Check_Kind ("nest[0]",
                  CBOR.MT_Array, R.Items (1).Kind);
      Check_Kind ("nest[1]",
                  CBOR.MT_Array, R.Items (2).Kind);
      Check_Kind ("nest[2]",
                  CBOR.MT_Unsigned_Integer,
                  R.Items (3).Kind);
      Check ("nest[2] val", 42, R.Items (3).UInt_Value);
      Check_Kind ("nest[3]",
                  CBOR.MT_Simple_Value,
                  R.Items (4).Kind);
   end Test_Decode_All_Nested;

   procedure Test_Decode_All_Tag is
      E : constant Stream_Element_Array :=
        Enc.Encode_Tag (0)
        & Enc.Encode_Text_String ("2023-01-01");
      R : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (E);
   begin
      TIO.Put_Line ("  Decode_All tag:");
      Check_Status ("tag status", CBOR.OK, R.Status);
      Check ("tag count", 2, UInt64 (R.Count));
      Check_Kind ("tag[0]",
                  CBOR.MT_Tag, R.Items (1).Kind);
      Check ("tag[0] num", 0, R.Items (1).Tag_Number);
      Check_Kind ("tag[1]",
                  CBOR.MT_Text_String,
                  R.Items (2).Kind);
   end Test_Decode_All_Tag;

   procedure Test_Decode_All_Empty is
      E : constant Stream_Element_Array :=
        Enc.Encode_Unsigned (42);
      R : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (E);
   begin
      TIO.Put_Line ("  Decode_All leaf:");
      Check_Status ("leaf status", CBOR.OK, R.Status);
      Check ("leaf count", 1, UInt64 (R.Count));
      Check ("leaf val", 42, R.Items (1).UInt_Value);
   end Test_Decode_All_Empty;

   procedure Test_Decode_All_Indefinite is
      E : constant Stream_Element_Array :=
        Enc.Encode_Array_Start
        & Enc.Encode_Unsigned (1)
        & Enc.Encode_Unsigned (2)
        & Enc.Encode_Break;
      R : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (E);
   begin
      TIO.Put_Line ("  Decode_All indefinite:");
      Check_Status ("indef status", CBOR.OK, R.Status);
      Check ("indef count", 4, UInt64 (R.Count));
      Check_Kind ("indef[0]",
                  CBOR.MT_Array, R.Items (1).Kind);
      Check ("indef[0] cnt",
             UInt64'Last, R.Items (1).Arr_Count);
      Check ("indef[1] val", 1, R.Items (2).UInt_Value);
      Check ("indef[2] val", 2, R.Items (3).UInt_Value);
      Check_Kind ("indef[3]",
                  CBOR.MT_Simple_Value,
                  R.Items (4).Kind);
      Check ("indef[3] sv", 31,
             UInt64 (R.Items (4).SV_Value));
   end Test_Decode_All_Indefinite;

   procedure Test_Decode_All_Depth is
      Depth_16 : constant Stream_Element_Array (1 .. 17) :=
        [1 .. 16 => 16#81#, 17 => 16#00#];
      Depth_17 : constant Stream_Element_Array (1 .. 18) :=
        [1 .. 17 => 16#81#, 18 => 16#00#];
      R16 : CBOR.Decode_All_Result;
      R17 : CBOR.Decode_All_Result;
   begin
      TIO.Put_Line ("  Decode_All depth:");
      R16 := Dec.Decode_All (Depth_16);
      Check_Status ("depth16",
                    CBOR.OK, R16.Status);
      R17 := Dec.Decode_All (Depth_17);
      Check_Status ("depth17",
                    CBOR.Err_Depth_Exceeded, R17.Status);
   end Test_Decode_All_Depth;

   procedure Test_Decode_All_Empty_Container is
      E : constant Stream_Element_Array :=
        Enc.Encode_Array (2)
        & Enc.Encode_Array (0)
        & Enc.Encode_Map (0);
      R : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (E);
   begin
      TIO.Put_Line ("  Decode_All empty containers:");
      Check_Status ("empty status", CBOR.OK, R.Status);
      Check ("empty count", 3, UInt64 (R.Count));
      Check_Kind ("empty[1]",
                  CBOR.MT_Array, R.Items (1).Kind);
      Check ("empty[1] cnt", 2, R.Items (1).Arr_Count);
      Check_Kind ("empty[2]",
                  CBOR.MT_Array, R.Items (2).Kind);
      Check ("empty[2] cnt", 0, R.Items (2).Arr_Count);
      Check_Kind ("empty[3]",
                  CBOR.MT_Map, R.Items (3).Kind);
      Check ("empty[3] cnt", 0, R.Items (3).Map_Count);
   end Test_Decode_All_Empty_Container;

   procedure Test_Decode_All_Map is
      E : constant Stream_Element_Array :=
        Enc.Encode_Map (2)
        & Enc.Encode_Text_String ("a")
        & Enc.Encode_Unsigned (1)
        & Enc.Encode_Text_String ("b")
        & Enc.Encode_Unsigned (2);
      R : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (E);
   begin
      TIO.Put_Line ("  Decode_All map:");
      Check_Status ("map status", CBOR.OK, R.Status);
      Check ("map count", 5, UInt64 (R.Count));
      Check_Kind ("map[0]",
                  CBOR.MT_Map, R.Items (1).Kind);
      Check ("map[0] cnt", 2, R.Items (1).Map_Count);
      Check_Kind ("map key1",
                  CBOR.MT_Text_String, R.Items (2).Kind);
      Check_Kind ("map val1",
                  CBOR.MT_Unsigned_Integer,
                  R.Items (3).Kind);
      Check ("map val1 v", 1, R.Items (3).UInt_Value);
   end Test_Decode_All_Map;

   procedure Test_UTF8 is
      Valid_ASCII : constant Stream_Element_Array :=
        [16#48#, 16#65#, 16#6C#, 16#6C#, 16#6F#];
      Valid_2Byte : constant Stream_Element_Array :=
        [16#C3#, 16#A9#];
      Valid_3Byte : constant Stream_Element_Array :=
        [16#E2#, 16#82#, 16#AC#];
      Valid_4Byte : constant Stream_Element_Array :=
        [16#F0#, 16#9F#, 16#98#, 16#80#];
      Invalid_Cont : constant Stream_Element_Array :=
        [16#C3#, 16#00#];
      Invalid_Start : constant Stream_Element_Array :=
        [16#80#];
      Invalid_Overlong : constant Stream_Element_Array :=
        [16#C0#, 16#80#];
      Invalid_Surrogate : constant Stream_Element_Array :=
        [16#ED#, 16#A0#, 16#80#];
      Empty : constant Stream_Element_Array (1 .. 0) :=
        [];
   begin
      TIO.Put_Line ("  UTF-8 validation:");
      Check ("utf8 ascii",
             (if Dec.Is_Valid_UTF8 (Valid_ASCII)
              then 1 else 0), 1);
      Check ("utf8 2byte",
             (if Dec.Is_Valid_UTF8 (Valid_2Byte)
              then 1 else 0), 1);
      Check ("utf8 3byte",
             (if Dec.Is_Valid_UTF8 (Valid_3Byte)
              then 1 else 0), 1);
      Check ("utf8 4byte",
             (if Dec.Is_Valid_UTF8 (Valid_4Byte)
              then 1 else 0), 1);
      Check ("utf8 bad cont",
             (if Dec.Is_Valid_UTF8 (Invalid_Cont)
              then 1 else 0), 0);
      Check ("utf8 bad start",
             (if Dec.Is_Valid_UTF8 (Invalid_Start)
              then 1 else 0), 0);
      Check ("utf8 overlong",
             (if Dec.Is_Valid_UTF8 (Invalid_Overlong)
              then 1 else 0), 0);
      Check ("utf8 surrogate",
             (if Dec.Is_Valid_UTF8 (Invalid_Surrogate)
              then 1 else 0), 0);
      Check ("utf8 empty",
             (if Dec.Is_Valid_UTF8 (Empty)
              then 1 else 0), 1);
   end Test_UTF8;

   procedure Test_Decode_All_UTF8 is
      Good : constant Stream_Element_Array :=
        Enc.Encode_Text_String ("Hello");
      Bad : constant Stream_Element_Array :=
        [16#63#, 16#C0#, 16#80#, 16#41#];
      R_Good : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (Good, Check_UTF8 => True);
      R_Bad  : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (Bad, Check_UTF8 => True);
   begin
      TIO.Put_Line ("  Decode_All UTF-8 check:");
      Check_Status ("utf8 good", CBOR.OK, R_Good.Status);
      Check_Status ("utf8 bad",
                    CBOR.Err_Invalid_UTF8, R_Bad.Status);
   end Test_Decode_All_UTF8;

   procedure Test_Shortest_Form is
      NF1 : constant CBOR.Decode_Result :=
        Dec.Decode ([16#18#, 16#00#]);
      NF2 : constant CBOR.Decode_Result :=
        Dec.Decode ([16#19#, 16#00#, 16#01#]);
      NF3 : constant CBOR.Decode_Result :=
        Dec.Decode ([16#38#, 16#17#]);
      OK1 : constant CBOR.Decode_Result :=
        Dec.Decode ([16#18#, 16#18#]);
   begin
      TIO.Put_Line ("  Shortest-form validation:");
      Check_Status ("nonshort 0",
                    CBOR.Err_Not_Well_Formed, NF1.Status);
      Check_Status ("nonshort 1",
                    CBOR.Err_Not_Well_Formed, NF2.Status);
      Check_Status ("nonshort neg",
                    CBOR.Err_Not_Well_Formed, NF3.Status);
      Check_Status ("shortest 24",
                    CBOR.OK, OK1.Status);
   end Test_Shortest_Form;

   procedure Test_Decode_Large is
      E : constant Stream_Element_Array :=
        [16#1b#, 16#00#, 16#00#, 16#00#,
         16#01#, 16#00#, 16#00#, 16#00#, 16#00#];
      R : constant CBOR.Decode_Result := Dec.Decode (E);
   begin
      TIO.Put_Line ("  Large value decode:");
      Check_Status ("u64 status", CBOR.OK, R.Status);
      Check ("u64 val", 16#1_0000_0000#, R.Item.UInt_Value);
   end Test_Decode_Large;

   procedure Test_RFC_Appendix_F is
      R1 : constant CBOR.Decode_Result :=
        Dec.Decode ([16#f8#, 16#00#]);
      R2 : constant CBOR.Decode_Result :=
        Dec.Decode ([16#f8#, 16#18#]);
      R3 : constant CBOR.Decode_Result :=
        Dec.Decode ([16#f8#, 16#1f#]);
   begin
      TIO.Put_Line ("  RFC Appendix F simple values:");
      Check_Status ("f8 00", CBOR.Err_Not_Well_Formed,
                    R1.Status);
      Check_Status ("f8 18", CBOR.Err_Not_Well_Formed,
                    R2.Status);
      Check_Status ("f8 1f", CBOR.Err_Not_Well_Formed,
                    R3.Status);
   end Test_RFC_Appendix_F;

   procedure Test_Chunk_Validation is
      BS_Chunk_OK : constant Stream_Element_Array :=
        [16#5f#, 16#42#, 16#01#, 16#02#,
         16#42#, 16#03#, 16#04#, 16#ff#];
      BS_Chunk_Bad : constant Stream_Element_Array :=
        [16#5f#, 16#00#, 16#ff#];
      TS_Chunk_Bad : constant Stream_Element_Array :=
        [16#7f#, 16#41#, 16#00#, 16#ff#];
      R_OK  : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (BS_Chunk_OK);
      R_Bad1 : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (BS_Chunk_Bad);
      R_Bad2 : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (TS_Chunk_Bad);
   begin
      TIO.Put_Line ("  Chunk validation:");
      Check_Status ("bs chunk ok", CBOR.OK, R_OK.Status);
      Check ("bs chunk count", 4,
             UInt64 (R_OK.Count));
      Check_Status ("bs chunk bad",
                    CBOR.Err_Not_Well_Formed,
                    R_Bad1.Status);
      Check_Status ("ts chunk bad",
                    CBOR.Err_Not_Well_Formed,
                    R_Bad2.Status);
   end Test_Chunk_Validation;

   procedure Test_Break_In_Definite is
      E : constant Stream_Element_Array :=
        [16#81#, 16#ff#];
      R : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (E);
   begin
      TIO.Put_Line ("  Break in definite container:");
      Check_Status ("break definite",
                    CBOR.Err_Not_Well_Formed, R.Status);
   end Test_Break_In_Definite;

   procedure Test_Indef_Map_Odd is
      E : constant Stream_Element_Array :=
        [16#bf#, 16#00#, 16#ff#];
      R : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (E);
   begin
      TIO.Put_Line ("  Indef map odd items:");
      Check_Status ("odd map",
                    CBOR.Err_Not_Well_Formed, R.Status);
   end Test_Indef_Map_Odd;

   procedure Test_Truncated_Nested is
      E : constant Stream_Element_Array :=
        [16#82#, 16#00#];
      R : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (E);
   begin
      TIO.Put_Line ("  Truncated nested:");
      Check_Status ("trunc nested",
                    CBOR.Err_Truncated, R.Status);
   end Test_Truncated_Nested;

   procedure Test_Float_Decode is
      Half_Input : constant Stream_Element_Array :=
        [16#F9#, 16#3C#, 16#00#];
      R_Half : constant CBOR.Decode_Result :=
        Dec.Decode (Half_Input);
      Half_Bytes : constant Stream_Element_Array :=
        Dec.Get_String (Half_Input, R_Half.Item.Float_Ref);

      Single_Input : constant Stream_Element_Array :=
        [16#FA#, 16#3F#, 16#80#, 16#00#, 16#00#];
      R_Single : constant CBOR.Decode_Result :=
        Dec.Decode (Single_Input);
      Single_Bytes : constant Stream_Element_Array :=
        Dec.Get_String (Single_Input, R_Single.Item.Float_Ref);

      Double_Input : constant Stream_Element_Array :=
        [16#FB#, 16#3F#, 16#F0#, 16#00#, 16#00#,
         16#00#, 16#00#, 16#00#, 16#00#];
      R_Double : constant CBOR.Decode_Result :=
        Dec.Decode (Double_Input);
      Double_Bytes : constant Stream_Element_Array :=
        Dec.Get_String (Double_Input, R_Double.Item.Float_Ref);
   begin
      TIO.Put_Line ("  Float decode:");
      Check_Status ("half status", CBOR.OK, R_Half.Status);
      Check_Kind ("half kind",
                  CBOR.MT_Simple_Value, R_Half.Item.Kind);
      Check ("half sv", 25, UInt64 (R_Half.Item.SV_Value));
      Check ("half ref len", 2,
             UInt64 (R_Half.Item.Float_Ref.Length));
      Check ("half byte1", 16#3C#, UInt64 (Half_Bytes (1)));
      Check ("half byte2", 16#00#, UInt64 (Half_Bytes (2)));

      Check_Status ("single status", CBOR.OK, R_Single.Status);
      Check ("single sv", 26, UInt64 (R_Single.Item.SV_Value));
      Check ("single ref len", 4,
             UInt64 (R_Single.Item.Float_Ref.Length));
      Check ("single byte1", 16#3F#, UInt64 (Single_Bytes (1)));
      Check ("single byte4", 16#00#, UInt64 (Single_Bytes (4)));

      Check_Status ("double status", CBOR.OK, R_Double.Status);
      Check ("double sv", 27, UInt64 (R_Double.Item.SV_Value));
      Check ("double ref len", 8,
             UInt64 (R_Double.Item.Float_Ref.Length));
      Check ("double byte1", 16#3F#, UInt64 (Double_Bytes (1)));
      Check ("double byte8", 16#00#, UInt64 (Double_Bytes (8)));
   end Test_Float_Decode;

   procedure Test_Top_Level_Break is
      E : constant Stream_Element_Array := [16#FF#];
      R_Dec : constant CBOR.Decode_Result :=
        Dec.Decode (E);
      R_All : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (E);
   begin
      TIO.Put_Line ("  Top-level break:");
      Check_Status ("toplevel break dec",
                    CBOR.Err_Not_Well_Formed, R_Dec.Status);
      Check_Status ("toplevel break all",
                    CBOR.Err_Not_Well_Formed, R_All.Status);
   end Test_Top_Level_Break;

   procedure Test_Empty_Strings is
      BS_Empty : constant Stream_Element_Array := [16#40#];
      R_BS : constant CBOR.Decode_Result :=
        Dec.Decode (BS_Empty);
      TS_Empty : constant Stream_Element_Array := [16#60#];
      R_TS : constant CBOR.Decode_Result :=
        Dec.Decode (TS_Empty);
   begin
      TIO.Put_Line ("  Empty strings:");
      Check_Status ("empty bs status", CBOR.OK, R_BS.Status);
      Check_Kind ("empty bs kind",
                  CBOR.MT_Byte_String, R_BS.Item.Kind);
      Check ("empty bs len", 0,
             UInt64 (R_BS.Item.BS_Ref.Length));

      Check_Status ("empty ts status", CBOR.OK, R_TS.Status);
      Check_Kind ("empty ts kind",
                  CBOR.MT_Text_String, R_TS.Item.Kind);
      Check ("empty ts len", 0,
             UInt64 (R_TS.Item.TS_Ref.Length));

      declare
         Empty_Bytes : constant Stream_Element_Array :=
           Dec.Get_String (BS_Empty, R_BS.Item.BS_Ref);
      begin
         Check ("empty get len", 0,
                UInt64 (Empty_Bytes'Length));
      end;
   end Test_Empty_Strings;

   procedure Test_Decode_All_Strict is
      Exact : constant Stream_Element_Array :=
        Enc.Encode_Unsigned (42);
      R_Exact : constant CBOR.Decode_All_Result :=
        Dec.Decode_All_Strict (Exact);
      Trailing : constant Stream_Element_Array :=
        Enc.Encode_Unsigned (42) & [16#00#];
      R_Trailing : constant CBOR.Decode_All_Result :=
        Dec.Decode_All_Strict (Trailing);
      R_Permissive : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (Trailing);
   begin
      TIO.Put_Line ("  Decode_All_Strict:");
      Check_Status ("strict exact", CBOR.OK, R_Exact.Status);
      Check ("strict exact count", 1,
             UInt64 (R_Exact.Count));
      Check_Status ("strict trailing",
                    CBOR.Err_Truncated, R_Trailing.Status);
      Check_Status ("permissive trailing",
                    CBOR.OK, R_Permissive.Status);
   end Test_Decode_All_Strict;

   package Rand_U64 is new Ada.Numerics.Discrete_Random
     (CBOR.UInt64);

   Gen : Rand_U64.Generator;

   procedure Test_Round_Trip_Unsigned is
      Edge : constant array (1 .. 11) of UInt64 :=
        [0, 1, 23, 24, 255, 256, 65535, 65536,
         16#FFFF_FFFF#, 16#1_0000_0000#, UInt64'Last];
   begin
      TIO.Put_Line ("  Round-trip unsigned:");
      for I in Edge'Range loop
         declare
            E : constant Stream_Element_Array :=
              Enc.Encode_Unsigned (Edge (I));
            R : constant CBOR.Decode_Result :=
              Dec.Decode (E);
         begin
            Check_Status ("rt_u status" & I'Image,
                          CBOR.OK, R.Status);
            Check_Kind ("rt_u kind" & I'Image,
                        CBOR.MT_Unsigned_Integer, R.Item.Kind);
            Check ("rt_u value" & I'Image,
                   Edge (I), R.Item.UInt_Value);
         end;
      end loop;
      for I in 1 .. 20 loop
         declare
            V : constant UInt64 := Rand_U64.Random (Gen);
            E : constant Stream_Element_Array :=
              Enc.Encode_Unsigned (V);
            R : constant CBOR.Decode_Result :=
              Dec.Decode (E);
         begin
            Check ("rt_u rand" & I'Image, V, R.Item.UInt_Value);
         end;
      end loop;
   end Test_Round_Trip_Unsigned;

   procedure Test_Round_Trip_Negative is
      Edge : constant array (1 .. 11) of UInt64 :=
        [0, 1, 23, 24, 255, 256, 65535, 65536,
         16#FFFF_FFFF#, 16#1_0000_0000#, UInt64'Last];
   begin
      TIO.Put_Line ("  Round-trip negative:");
      for I in Edge'Range loop
         declare
            E : constant Stream_Element_Array :=
              Enc.Encode_Negative (Edge (I));
            R : constant CBOR.Decode_Result :=
              Dec.Decode (E);
         begin
            Check_Status ("rt_n status" & I'Image,
                          CBOR.OK, R.Status);
            Check_Kind ("rt_n kind" & I'Image,
                        CBOR.MT_Negative_Integer, R.Item.Kind);
            Check ("rt_n arg" & I'Image,
                   Edge (I), R.Item.NInt_Arg);
         end;
      end loop;
      for I in 1 .. 20 loop
         declare
            V : constant UInt64 := Rand_U64.Random (Gen);
            E : constant Stream_Element_Array :=
              Enc.Encode_Negative (V);
            R : constant CBOR.Decode_Result :=
              Dec.Decode (E);
         begin
            Check ("rt_n rand" & I'Image, V, R.Item.NInt_Arg);
         end;
      end loop;
   end Test_Round_Trip_Negative;

   procedure Test_Round_Trip_Simple_Types is
   begin
      TIO.Put_Line ("  Round-trip simple types:");
      declare
         Rt : constant Stream_Element_Array :=
           Enc.Encode_Bool (True);
         Rf : constant Stream_Element_Array :=
           Enc.Encode_Bool (False);
         DT : constant CBOR.Decode_Result := Dec.Decode (Rt);
         DF : constant CBOR.Decode_Result := Dec.Decode (Rf);
      begin
         Check ("rt_bool true sv", 21,
                UInt64 (DT.Item.SV_Value));
         Check ("rt_bool false sv", 20,
                UInt64 (DF.Item.SV_Value));
      end;
      declare
         E : constant Stream_Element_Array := Enc.Encode_Null;
         R : constant CBOR.Decode_Result := Dec.Decode (E);
      begin
         Check ("rt_null sv", 22,
                UInt64 (R.Item.SV_Value));
      end;
      declare
         E : constant Stream_Element_Array :=
           Enc.Encode_Undefined;
         R : constant CBOR.Decode_Result := Dec.Decode (E);
      begin
         Check ("rt_undef sv", 23,
                UInt64 (R.Item.SV_Value));
      end;
      for SV in 0 .. 23 loop
         declare
            E : constant Stream_Element_Array :=
              Enc.Encode_Simple (UInt64 (SV));
            R : constant CBOR.Decode_Result :=
              Dec.Decode (E);
         begin
            Check ("rt_simple" & SV'Image,
                   UInt64 (SV), UInt64 (R.Item.SV_Value));
         end;
      end loop;
      for SV in 32 .. 255 loop
         declare
            E : constant Stream_Element_Array :=
              Enc.Encode_Simple (UInt64 (SV));
            R : constant CBOR.Decode_Result :=
              Dec.Decode (E);
         begin
            Check ("rt_simple" & SV'Image,
                   UInt64 (SV), UInt64 (R.Item.SV_Value));
         end;
      end loop;
   end Test_Round_Trip_Simple_Types;

   procedure Test_Round_Trip_Tag is
      Edge : constant array (1 .. 8) of UInt64 :=
        [0, 1, 23, 24, 255, 65535,
         16#1_0000_0000#, UInt64'Last];
   begin
      TIO.Put_Line ("  Round-trip tag:");
      for I in Edge'Range loop
         declare
            E : constant Stream_Element_Array :=
              Enc.Encode_Tag (Edge (I));
            R : constant CBOR.Decode_Result :=
              Dec.Decode (E);
         begin
            Check ("rt_tag" & I'Image,
                   Edge (I), R.Item.Tag_Number);
         end;
      end loop;
      for I in 1 .. 20 loop
         declare
            V : constant UInt64 := Rand_U64.Random (Gen);
            E : constant Stream_Element_Array :=
              Enc.Encode_Tag (V);
            R : constant CBOR.Decode_Result :=
              Dec.Decode (E);
         begin
            Check ("rt_tag rand" & I'Image, V, R.Item.Tag_Number);
         end;
      end loop;
   end Test_Round_Trip_Tag;

   procedure Test_Round_Trip_Strings is
      Lengths : constant array (1 .. 5) of Stream_Element_Offset :=
        [0, 1, 23, 24, 256];
   begin
      TIO.Put_Line ("  Round-trip strings:");
      for J in Lengths'Range loop
         declare
            Len : constant Stream_Element_Offset := Lengths (J);
            Raw : Stream_Element_Array (1 .. Len) :=
              [others => 0];
         begin
            for I in 1 .. Len loop
               Raw (I) := Stream_Element
                 ((I * 37 + 13) mod 256);
            end loop;
            declare
               E : constant Stream_Element_Array :=
                 Enc.Encode_Byte_String (Raw);
               R : constant CBOR.Decode_Result :=
                 Dec.Decode (E);
               D : constant Stream_Element_Array :=
                 Dec.Get_String (E, R.Item.BS_Ref);
            begin
               Check ("rt_bs len" & Len'Image,
                      UInt64 (R.Item.BS_Ref.Length),
                      UInt64 (Len));
               if Len > 0 then
                  Check ("rt_bs first" & Len'Image,
                         UInt64 (D (1)), UInt64 (Raw (1)));
                  Check ("rt_bs last" & Len'Image,
                         UInt64 (D (Len)), UInt64 (Raw (Len)));
               end if;
            end;
         end;
      end loop;
      for J in Lengths'Range loop
         declare
            Len  : constant Stream_Element_Offset := Lengths (J);
            Text : String (1 .. Integer (Len)) :=
              [others => 'A'];
         begin
            for I in 1 .. Integer (Len) loop
               Text (I) :=
                 Character'Val ((I * 37 + 13) mod 95 + 32);
            end loop;
            declare
               E : constant Stream_Element_Array :=
                 Enc.Encode_Text_String (Text);
               R : constant CBOR.Decode_Result :=
                 Dec.Decode (E);
               D : constant Stream_Element_Array :=
                 Dec.Get_String (E, R.Item.TS_Ref);
            begin
               Check ("rt_ts len" & Len'Image,
                      UInt64 (R.Item.TS_Ref.Length),
                      UInt64 (Len));
                if Len > 0 then
                  Check ("rt_ts byte1" & Len'Image,
                         UInt64 (D (1)),
                         UInt64 (Character'Pos (Text (1))));
                  Check ("rt_ts byteN" & Len'Image,
                         UInt64 (D (Len)),
                         UInt64 (Character'Pos
                           (Text (Integer (Len)))));
               end if;
            end;
         end;
      end loop;
   end Test_Round_Trip_Strings;

   procedure Test_Round_Trip_Floats is
   begin
      TIO.Put_Line ("  Round-trip floats:");
      declare
         Half_In : constant Stream_Element_Array :=
           [16#3C#, 16#00#];
         E : constant Stream_Element_Array :=
           Enc.Encode_Float_Half (Half_In);
         R : constant CBOR.Decode_Result := Dec.Decode (E);
         D : constant Stream_Element_Array :=
           Dec.Get_String (E, R.Item.Float_Ref);
      begin
         Check ("rt_f16 sv", 25,
                UInt64 (R.Item.SV_Value));
         Check ("rt_f16 len", 2,
                UInt64 (R.Item.Float_Ref.Length));
         Check ("rt_f16 b1", 16#3C#, UInt64 (D (1)));
         Check ("rt_f16 b2", 16#00#, UInt64 (D (2)));
      end;
      declare
         Single_In : constant Stream_Element_Array :=
           [16#3F#, 16#80#, 16#00#, 16#00#];
         E : constant Stream_Element_Array :=
           Enc.Encode_Float_Single (Single_In);
         R : constant CBOR.Decode_Result := Dec.Decode (E);
         D : constant Stream_Element_Array :=
           Dec.Get_String (E, R.Item.Float_Ref);
      begin
         Check ("rt_f32 sv", 26,
                UInt64 (R.Item.SV_Value));
         Check ("rt_f32 len", 4,
                UInt64 (R.Item.Float_Ref.Length));
         Check ("rt_f32 b1", 16#3F#, UInt64 (D (1)));
         Check ("rt_f32 b4", 16#00#, UInt64 (D (4)));
      end;
      declare
         Double_In : constant Stream_Element_Array :=
           [16#3F#, 16#F0#, 16#00#, 16#00#,
            16#00#, 16#00#, 16#00#, 16#00#];
         E : constant Stream_Element_Array :=
           Enc.Encode_Float_Double (Double_In);
         R : constant CBOR.Decode_Result := Dec.Decode (E);
         D : constant Stream_Element_Array :=
           Dec.Get_String (E, R.Item.Float_Ref);
      begin
         Check ("rt_f64 sv", 27,
                UInt64 (R.Item.SV_Value));
         Check ("rt_f64 len", 8,
                UInt64 (R.Item.Float_Ref.Length));
         Check ("rt_f64 b1", 16#3F#, UInt64 (D (1)));
         Check ("rt_f64 b2", 16#F0#, UInt64 (D (2)));
         Check ("rt_f64 b8", 16#00#, UInt64 (D (8)));
      end;
   end Test_Round_Trip_Floats;

   procedure Test_Round_Trip_Containers is
      Counts : constant array (1 .. 5) of UInt64 :=
        [0, 1, 23, 24, 255];
   begin
      TIO.Put_Line ("  Round-trip containers:");
      for J in Counts'Range loop
         declare
            Cnt : constant UInt64 := Counts (J);
            EA  : constant Stream_Element_Array :=
              Enc.Encode_Array (Cnt);
            RA  : constant CBOR.Decode_Result :=
              Dec.Decode (EA);
            EM  : constant Stream_Element_Array :=
              Enc.Encode_Map (Cnt);
            RM  : constant CBOR.Decode_Result :=
              Dec.Decode (EM);
         begin
            Check ("rt_arr" & J'Image & " cnt",
                   Cnt, RA.Item.Arr_Count);
            Check ("rt_map" & J'Image & " cnt",
                   Cnt, RM.Item.Map_Count);
         end;
      end loop;
      declare
         E : constant Stream_Element_Array :=
           Enc.Encode_Array (3)
           & Enc.Encode_Unsigned (1)
           & Enc.Encode_Text_String ("hi")
           & Enc.Encode_Bool (False);
         R : constant CBOR.Decode_All_Result :=
           Dec.Decode_All (E);
      begin
         Check_Status ("rt_struct status", CBOR.OK, R.Status);
         Check ("rt_struct count", 4, UInt64 (R.Count));
         Check_Kind ("rt_struct[1]",
                     CBOR.MT_Array, R.Items (1).Kind);
         Check ("rt_struct[1] cnt", 3, R.Items (1).Arr_Count);
         Check_Kind ("rt_struct[2]",
                     CBOR.MT_Unsigned_Integer,
                     R.Items (2).Kind);
         Check ("rt_struct[2] val", 1, R.Items (2).UInt_Value);
         Check_Kind ("rt_struct[3]",
                     CBOR.MT_Text_String,
                     R.Items (3).Kind);
         Check_Kind ("rt_struct[4]",
                     CBOR.MT_Simple_Value,
                     R.Items (4).Kind);
         Check ("rt_struct[4] sv", 20,
                UInt64 (R.Items (4).SV_Value));
      end;
   end Test_Round_Trip_Containers;

begin
   Rand_U64.Reset (Gen);
   TIO.Put_Line ("=== CBOR Ada Test Suite ===");
   TIO.New_Line;

   Test_RFC8949_Encoding;
   Test_Decode_Strings;
   Test_Decode_Byte_String;
   Test_Decode_Nested;
   Test_Well_Formedness;
   Test_New_Features;
   Test_Decode_Raw;
   Test_Decode_All_Basic;
   Test_Decode_All_Nested;
   Test_Decode_All_Tag;
   Test_Decode_All_Empty;
   Test_Decode_All_Indefinite;
   Test_Decode_All_Depth;
   Test_Decode_All_Empty_Container;
   Test_Decode_All_Map;
   Test_UTF8;
   Test_Decode_All_UTF8;
   Test_Shortest_Form;
   Test_Decode_Large;
   Test_RFC_Appendix_F;
   Test_Chunk_Validation;
   Test_Break_In_Definite;
   Test_Indef_Map_Odd;
   Test_Truncated_Nested;
   Test_Float_Decode;
   Test_Top_Level_Break;
   Test_Empty_Strings;
   Test_Decode_All_Strict;

   Test_Round_Trip_Unsigned;
   Test_Round_Trip_Negative;
   Test_Round_Trip_Simple_Types;
   Test_Round_Trip_Tag;
   Test_Round_Trip_Strings;
   Test_Round_Trip_Floats;
   Test_Round_Trip_Containers;

   TIO.New_Line;
   TIO.Put_Line ("=== Results ===");
   TIO.Put_Line ("Passes:" & Passes'Image);
   TIO.Put_Line ("Fails: " & Fails'Image);

   if Fails > 0 then
      TIO.Put_Line ("SOME TESTS FAILED");
      GNAT.OS_Lib.OS_Exit (1);
   else
      TIO.Put_Line ("ALL TESTS PASSED");
   end if;
end Test_Cbor;
