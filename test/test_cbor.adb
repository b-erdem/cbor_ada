with CBOR;
with CBOR.Encoding;
with CBOR.Decoding;
with System.Storage_Elements;
with Ada.Numerics.Discrete_Random;
with Ada.Text_IO;
with GNAT.OS_Lib;
with Interfaces;

procedure Test_Cbor is

   use type System.Storage_Elements.Storage_Element;
   use type System.Storage_Elements.Storage_Array;
   use type System.Storage_Elements.Storage_Offset;
   use CBOR;
   use type CBOR.UInt64;
   use Interfaces;
   use System.Storage_Elements;

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
      Expected : Storage_Array;
      Actual   : Storage_Array)
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
      for I in Storage_Offset range
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
      E  : constant Storage_Array :=
        Enc.Encode_Text_String ("hello");
      R  : constant CBOR.Decode_Result :=
        Dec.Decode (E);
      S  : constant Storage_Array :=
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
      Raw : constant Storage_Array :=
        [16#de#, 16#ad#, 16#be#, 16#ef#];
      E   : constant Storage_Array :=
        Enc.Encode_Byte_String (Raw);
      R   : constant CBOR.Decode_Result :=
        Dec.Decode (E);
      S   : constant Storage_Array :=
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
      E : constant Storage_Array :=
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
      R2 := Dec.Decode (E, R1.Next);
      Check_Status ("elem1 status", CBOR.OK, R2.Status);
      Check ("elem1 value", 1, R2.Item.UInt_Value);
      R3 := Dec.Decode (E, R2.Next);
      Check_Status ("elem2 status", CBOR.OK, R3.Status);
      Check ("elem2 sv", 21,
             UInt64 (R3.Item.SV_Value));
   end Test_Decode_Nested;

   procedure Test_Well_Formedness is
      Bad1 : constant Storage_Array := [16#1c#];
      R1   : constant CBOR.Decode_Result :=
        Dec.Decode (Bad1);
      Bad2 : constant Storage_Array :=
        [16#f8#, 16#10#];
      R2   : constant CBOR.Decode_Result :=
        Dec.Decode (Bad2);
      Trunc : constant Storage_Array := [16#19#];
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
         Float_Bytes : constant Storage_Array :=
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
      E : constant Storage_Array :=
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
      E : constant Storage_Array :=
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
      E : constant Storage_Array :=
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
      E : constant Storage_Array :=
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
      E : constant Storage_Array :=
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
      Depth_16 : constant Storage_Array (1 .. 17) :=
        [1 .. 16 => 16#81#, 17 => 16#00#];
      Depth_17 : constant Storage_Array (1 .. 18) :=
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
      E : constant Storage_Array :=
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
      E : constant Storage_Array :=
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
      Valid_ASCII : constant Storage_Array :=
        [16#48#, 16#65#, 16#6C#, 16#6C#, 16#6F#];
      Valid_2Byte : constant Storage_Array :=
        [16#C3#, 16#A9#];
      Valid_3Byte : constant Storage_Array :=
        [16#E2#, 16#82#, 16#AC#];
      Valid_4Byte : constant Storage_Array :=
        [16#F0#, 16#9F#, 16#98#, 16#80#];
      Invalid_Cont : constant Storage_Array :=
        [16#C3#, 16#00#];
      Invalid_Start : constant Storage_Array :=
        [16#80#];
      Invalid_Overlong : constant Storage_Array :=
        [16#C0#, 16#80#];
      Invalid_Surrogate : constant Storage_Array :=
        [16#ED#, 16#A0#, 16#80#];
      Empty : constant Storage_Array (1 .. 0) :=
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
      Good : constant Storage_Array :=
        Enc.Encode_Text_String ("Hello");
      Bad : constant Storage_Array :=
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
      E : constant Storage_Array :=
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
      BS_Chunk_OK : constant Storage_Array :=
        [16#5f#, 16#42#, 16#01#, 16#02#,
         16#42#, 16#03#, 16#04#, 16#ff#];
      BS_Chunk_Bad : constant Storage_Array :=
        [16#5f#, 16#00#, 16#ff#];
      TS_Chunk_Bad : constant Storage_Array :=
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
      E : constant Storage_Array :=
        [16#81#, 16#ff#];
      R : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (E);
   begin
      TIO.Put_Line ("  Break in definite container:");
      Check_Status ("break definite",
                    CBOR.Err_Not_Well_Formed, R.Status);
   end Test_Break_In_Definite;

   procedure Test_Indef_Map_Odd is
      E : constant Storage_Array :=
        [16#bf#, 16#00#, 16#ff#];
      R : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (E);
   begin
      TIO.Put_Line ("  Indef map odd items:");
      Check_Status ("odd map",
                    CBOR.Err_Not_Well_Formed, R.Status);
   end Test_Indef_Map_Odd;

   procedure Test_Truncated_Nested is
      E : constant Storage_Array :=
        [16#82#, 16#00#];
      R : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (E);
   begin
      TIO.Put_Line ("  Truncated nested:");
      Check_Status ("trunc nested",
                    CBOR.Err_Truncated, R.Status);
   end Test_Truncated_Nested;

   procedure Test_Float_Decode is
      Half_Input : constant Storage_Array :=
        [16#F9#, 16#3C#, 16#00#];
      R_Half : constant CBOR.Decode_Result :=
        Dec.Decode (Half_Input);
      Half_Bytes : constant Storage_Array :=
        Dec.Get_String (Half_Input, R_Half.Item.Float_Ref);

      Single_Input : constant Storage_Array :=
        [16#FA#, 16#3F#, 16#80#, 16#00#, 16#00#];
      R_Single : constant CBOR.Decode_Result :=
        Dec.Decode (Single_Input);
      Single_Bytes : constant Storage_Array :=
        Dec.Get_String (Single_Input, R_Single.Item.Float_Ref);

      Double_Input : constant Storage_Array :=
        [16#FB#, 16#3F#, 16#F0#, 16#00#, 16#00#,
         16#00#, 16#00#, 16#00#, 16#00#];
      R_Double : constant CBOR.Decode_Result :=
        Dec.Decode (Double_Input);
      Double_Bytes : constant Storage_Array :=
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
      E : constant Storage_Array := [16#FF#];
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
      BS_Empty : constant Storage_Array := [16#40#];
      R_BS : constant CBOR.Decode_Result :=
        Dec.Decode (BS_Empty);
      TS_Empty : constant Storage_Array := [16#60#];
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
         Empty_Bytes : constant Storage_Array :=
           Dec.Get_String (BS_Empty, R_BS.Item.BS_Ref);
      begin
         Check ("empty get len", 0,
                UInt64 (Empty_Bytes'Length));
      end;
   end Test_Empty_Strings;

   procedure Test_Decode_All_Strict is
      Exact : constant Storage_Array :=
        Enc.Encode_Unsigned (42);
      R_Exact : constant CBOR.Decode_All_Result :=
        Dec.Decode_All_Strict (Exact);
      Trailing : constant Storage_Array :=
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
                    CBOR.Err_Trailing_Data, R_Trailing.Status);
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
            E : constant Storage_Array :=
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
            E : constant Storage_Array :=
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
            E : constant Storage_Array :=
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
            E : constant Storage_Array :=
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
         Rt : constant Storage_Array :=
           Enc.Encode_Bool (True);
         Rf : constant Storage_Array :=
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
         E : constant Storage_Array := Enc.Encode_Null;
         R : constant CBOR.Decode_Result := Dec.Decode (E);
      begin
         Check ("rt_null sv", 22,
                UInt64 (R.Item.SV_Value));
      end;
      declare
         E : constant Storage_Array :=
           Enc.Encode_Undefined;
         R : constant CBOR.Decode_Result := Dec.Decode (E);
      begin
         Check ("rt_undef sv", 23,
                UInt64 (R.Item.SV_Value));
      end;
      for SV in 0 .. 23 loop
         declare
            E : constant Storage_Array :=
              Enc.Encode_Simple (Unsigned_8 (SV));
            R : constant CBOR.Decode_Result :=
              Dec.Decode (E);
         begin
            Check ("rt_simple" & SV'Image,
                   UInt64 (SV), UInt64 (R.Item.SV_Value));
         end;
      end loop;
      for SV in 32 .. 255 loop
         declare
            E : constant Storage_Array :=
              Enc.Encode_Simple (Unsigned_8 (SV));
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
            E : constant Storage_Array :=
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
            E : constant Storage_Array :=
              Enc.Encode_Tag (V);
            R : constant CBOR.Decode_Result :=
              Dec.Decode (E);
         begin
            Check ("rt_tag rand" & I'Image, V, R.Item.Tag_Number);
         end;
      end loop;
   end Test_Round_Trip_Tag;

   procedure Test_Round_Trip_Strings is
      Lengths : constant array (1 .. 5) of Storage_Offset :=
        [0, 1, 23, 24, 256];
   begin
      TIO.Put_Line ("  Round-trip strings:");
      for J in Lengths'Range loop
         declare
            Len : constant Storage_Offset := Lengths (J);
            Raw : Storage_Array (1 .. Len) :=
              [others => 0];
         begin
            for I in 1 .. Len loop
               Raw (I) := Storage_Element
                 ((I * 37 + 13) mod 256);
            end loop;
            declare
               E : constant Storage_Array :=
                 Enc.Encode_Byte_String (Raw);
               R : constant CBOR.Decode_Result :=
                 Dec.Decode (E);
               D : constant Storage_Array :=
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
            Len  : constant Storage_Offset := Lengths (J);
            Text : String (1 .. Integer (Len)) :=
              [others => 'A'];
         begin
            for I in 1 .. Integer (Len) loop
               Text (I) :=
                 Character'Val ((I * 37 + 13) mod 95 + 32);
            end loop;
            declare
               E : constant Storage_Array :=
                 Enc.Encode_Text_String (Text);
               R : constant CBOR.Decode_Result :=
                 Dec.Decode (E);
               D : constant Storage_Array :=
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
         Half_In : constant Storage_Array :=
           [16#3C#, 16#00#];
         E : constant Storage_Array :=
           Enc.Encode_Float_Half (Half_In);
         R : constant CBOR.Decode_Result := Dec.Decode (E);
         D : constant Storage_Array :=
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
         Single_In : constant Storage_Array :=
           [16#3F#, 16#80#, 16#00#, 16#00#];
         E : constant Storage_Array :=
           Enc.Encode_Float_Single (Single_In);
         R : constant CBOR.Decode_Result := Dec.Decode (E);
         D : constant Storage_Array :=
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
         Double_In : constant Storage_Array :=
           [16#3F#, 16#F0#, 16#00#, 16#00#,
            16#00#, 16#00#, 16#00#, 16#00#];
         E : constant Storage_Array :=
           Enc.Encode_Float_Double (Double_In);
         R : constant CBOR.Decode_Result := Dec.Decode (E);
         D : constant Storage_Array :=
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
            EA  : constant Storage_Array :=
              Enc.Encode_Array (Cnt);
            RA  : constant CBOR.Decode_Result :=
              Dec.Decode (EA);
            EM  : constant Storage_Array :=
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
         E : constant Storage_Array :=
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

   procedure Test_Too_Many_Items is
      --  Build an array of 128 unsigned integers (hitting Max_Decode_Items)
      Hdr : constant Storage_Array :=
        Enc.Encode_Array (128);
      Buf : Storage_Array (1 .. Hdr'Length + 128) :=
        [others => 0];
      Pos : Storage_Offset := 1;
      R128 : CBOR.Decode_All_Result;
   begin
      TIO.Put_Line ("  Too many items:");
      --  Fill buf with header + 128 x encode_unsigned(0) = 128 x 0x00
      for I in Hdr'Range loop
         Buf (Pos) := Hdr (I);
         Pos := Pos + 1;
      end loop;
      --  Each Encode_Unsigned(0) is a single byte 0x00
      --  Already filled with zeros, so done.
      R128 := Dec.Decode_All (Buf);
      --  Array header (1 item) + 128 elements = 129 total items
      --  This exceeds Max_Decode_Items = 128
      Check_Status ("128 elems",
                    CBOR.Err_Too_Many_Items, R128.Status);

      --  Verify that 127 elements (128 total items) works
      declare
         Hdr3 : constant Storage_Array :=
           Enc.Encode_Array (127);
         Buf3 : Storage_Array
           (1 .. Hdr3'Length + 127) := [others => 0];
         P3 : Storage_Offset := 1;
         R127 : CBOR.Decode_All_Result;
      begin
         for I in Hdr3'Range loop
            Buf3 (P3) := Hdr3 (I);
            P3 := P3 + 1;
         end loop;
         R127 := Dec.Decode_All (Buf3);
         Check_Status ("127 elems ok",
                       CBOR.OK, R127.Status);
         Check ("127 elems count", 128,
                UInt64 (R127.Count));
      end;
   end Test_Too_Many_Items;

   procedure Test_Nested_Indefinite is
      --  Indefinite array containing indefinite map with one k-v pair
      E : constant Storage_Array :=
        Enc.Encode_Array_Start            -- 0x9F
        & Enc.Encode_Map_Start            -- 0xBF
        & Enc.Encode_Unsigned (1)         -- key
        & Enc.Encode_Unsigned (2)         -- value
        & Enc.Encode_Break                -- close map
        & Enc.Encode_Break;               -- close array
      R : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (E);
   begin
      TIO.Put_Line ("  Nested indefinite:");
      Check_Status ("nested indef status",
                    CBOR.OK, R.Status);
      Check ("nested indef count", 6,
             UInt64 (R.Count));
      Check_Kind ("ni[0]",
                  CBOR.MT_Array, R.Items (1).Kind);
      Check ("ni[0] cnt",
             UInt64'Last, R.Items (1).Arr_Count);
      Check_Kind ("ni[1]",
                  CBOR.MT_Map, R.Items (2).Kind);
      Check ("ni[1] cnt",
             UInt64'Last, R.Items (2).Map_Count);
      Check ("ni[2] val", 1, R.Items (3).UInt_Value);
      Check ("ni[3] val", 2, R.Items (4).UInt_Value);
      --  Break items
      Check ("ni[4] sv", 31,
             UInt64 (R.Items (5).SV_Value));
      Check ("ni[5] sv", 31,
             UInt64 (R.Items (6).SV_Value));
   end Test_Nested_Indefinite;

   procedure Test_Decode_Pos_Edge is
      --  Two single-byte items: [10, 5], decode second via Pos
      E : constant Storage_Array :=
        Enc.Encode_Unsigned (10)
        & Enc.Encode_Unsigned (5);
      R1 : constant CBOR.Decode_Result := Dec.Decode (E);
      R2 : CBOR.Decode_Result;
      R3 : CBOR.Decode_Result;
   begin
      TIO.Put_Line ("  Decode Pos edge cases:");
      Check_Status ("pos edge r1", CBOR.OK, R1.Status);
      Check ("pos edge r1 val", 10, R1.Item.UInt_Value);
      R2 := Dec.Decode (E, R1.Next);
      Check_Status ("pos edge r2", CBOR.OK, R2.Status);
      Check ("pos edge r2 val", 5, R2.Item.UInt_Value);
      --  Decode at exactly Data'Last (single-byte item 0x05)
      R3 := Dec.Decode (E, E'Last);
      Check_Status ("pos at last", CBOR.OK, R3.Status);
      Check ("pos at last val", 5, R3.Item.UInt_Value);
   end Test_Decode_Pos_Edge;

   procedure Test_Indef_String_Success is
      --  Indefinite byte string with two chunks, decoded successfully
      BS : constant Storage_Array :=
        [16#5F#,                           -- indef byte string start
         16#42#, 16#CA#, 16#FE#,           -- chunk: 2 bytes
         16#43#, 16#DE#, 16#AD#, 16#00#,   -- chunk: 3 bytes
         16#FF#];                           -- break
      R : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (BS);
   begin
      TIO.Put_Line ("  Indef string success:");
      Check_Status ("indef bs status", CBOR.OK, R.Status);
      Check ("indef bs count", 4, UInt64 (R.Count));
      Check_Kind ("ibs[0]",
                  CBOR.MT_Byte_String, R.Items (1).Kind);
      --  First chunk
      Check_Kind ("ibs[1]",
                  CBOR.MT_Byte_String, R.Items (2).Kind);
      Check ("ibs[1] len", 2,
             UInt64 (R.Items (2).BS_Ref.Length));
      declare
         C1 : constant Storage_Array :=
           Dec.Get_String (BS, R.Items (2).BS_Ref);
      begin
         Check ("ibs[1] b1", 16#CA#, UInt64 (C1 (1)));
         Check ("ibs[1] b2", 16#FE#, UInt64 (C1 (2)));
      end;
      --  Second chunk
      Check ("ibs[2] len", 3,
             UInt64 (R.Items (3).BS_Ref.Length));
      declare
         C2 : constant Storage_Array :=
           Dec.Get_String (BS, R.Items (3).BS_Ref);
      begin
         Check ("ibs[2] b1", 16#DE#, UInt64 (C2 (1)));
         Check ("ibs[2] b2", 16#AD#, UInt64 (C2 (2)));
         Check ("ibs[2] b3", 16#00#, UInt64 (C2 (3)));
      end;
      --  Break
      Check ("ibs[3] sv", 31,
             UInt64 (R.Items (4).SV_Value));
   end Test_Indef_String_Success;

   procedure Test_TS_With_BS_Chunks is
      --  Indefinite text string with byte string chunks (wrong type)
      Bad : constant Storage_Array :=
        [16#7F#,                        -- indef text string start
         16#42#, 16#41#, 16#42#,        -- byte string chunk (wrong!)
         16#FF#];                        -- break
      R : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (Bad);
   begin
      TIO.Put_Line ("  Text string with byte string chunks:");
      Check_Status ("ts bs chunk",
                    CBOR.Err_Not_Well_Formed, R.Status);
   end Test_TS_With_BS_Chunks;

   procedure Test_Encode_Integer is
   begin
      TIO.Put_Line ("  Encode_Integer:");
      --  Positive values use major type 0
      Check_Enc ("int 0", [16#00#],
                 Enc.Encode_Integer (0));
      Check_Enc ("int 1", [16#01#],
                 Enc.Encode_Integer (1));
      Check_Enc ("int 23", [16#17#],
                 Enc.Encode_Integer (23));
      Check_Enc ("int 24", [16#18#, 16#18#],
                 Enc.Encode_Integer (24));
      Check_Enc ("int 1000",
                 [16#19#, 16#03#, 16#e8#],
                 Enc.Encode_Integer (1000));
      --  Negative values use major type 1
      Check_Enc ("int -1", [16#20#],
                 Enc.Encode_Integer (-1));
      Check_Enc ("int -10", [16#29#],
                 Enc.Encode_Integer (-10));
      Check_Enc ("int -100",
                 [16#38#, 16#63#],
                 Enc.Encode_Integer (-100));
      Check_Enc ("int -1000",
                 [16#39#, 16#03#, 16#e7#],
                 Enc.Encode_Integer (-1000));
      --  Round-trip: positive
      declare
         E : constant Storage_Array :=
           Enc.Encode_Integer (42);
         R : constant CBOR.Decode_Result := Dec.Decode (E);
      begin
         Check_Status ("int rt 42", CBOR.OK, R.Status);
         Check ("int rt 42 val", 42, R.Item.UInt_Value);
      end;
      --  Round-trip: negative
      declare
         E : constant Storage_Array :=
           Enc.Encode_Integer (-10);
         R : constant CBOR.Decode_Result := Dec.Decode (E);
      begin
         Check_Status ("int rt -10", CBOR.OK, R.Status);
         Check_Kind ("int rt -10 kind",
                     CBOR.MT_Negative_Integer, R.Item.Kind);
         Check ("int rt -10 arg", 9, R.Item.NInt_Arg);
      end;
      --  Integer_64'First = -2^63, Arg = 2^63 - 1
      declare
         E : constant Storage_Array :=
           Enc.Encode_Integer (Interfaces.Integer_64'First);
         R : constant CBOR.Decode_Result := Dec.Decode (E);
      begin
         Check_Status ("int rt min", CBOR.OK, R.Status);
         Check_Kind ("int rt min kind",
                     CBOR.MT_Negative_Integer, R.Item.Kind);
         Check ("int rt min arg",
                UInt64 (Interfaces.Integer_64'Last),
                R.Item.NInt_Arg);
      end;
      --  Integer_64'Last = 2^63 - 1
      declare
         E : constant Storage_Array :=
           Enc.Encode_Integer (Interfaces.Integer_64'Last);
         R : constant CBOR.Decode_Result := Dec.Decode (E);
      begin
         Check_Status ("int rt max", CBOR.OK, R.Status);
         Check ("int rt max val",
                UInt64 (Interfaces.Integer_64'Last),
                R.Item.UInt_Value);
      end;
   end Test_Encode_Integer;

   procedure Test_Max_Depth_Parameter is
      --  8 levels of nesting: [[[[[[[[0]]]]]]]]
      Depth_8 : constant Storage_Array (1 .. 9) :=
        [1 .. 8 => 16#81#, 9 => 16#00#];
   begin
      TIO.Put_Line ("  Max_Depth parameter:");
      --  Max_Depth = 8: should pass (depth exactly 8)
      declare
         R : constant CBOR.Decode_All_Result :=
           Dec.Decode_All (Depth_8, Max_Depth => 8);
      begin
         Check_Status ("depth 8 ok", CBOR.OK, R.Status);
         Check ("depth 8 count", 9, UInt64 (R.Count));
      end;
      --  Max_Depth = 7: should fail (needs 8)
      declare
         R : constant CBOR.Decode_All_Result :=
           Dec.Decode_All (Depth_8, Max_Depth => 7);
      begin
         Check_Status ("depth 7 fail",
                       CBOR.Err_Depth_Exceeded, R.Status);
      end;
      --  Max_Depth = 1: only flat items allowed
      declare
         Flat : constant Storage_Array :=
           Enc.Encode_Unsigned (42);
         R : constant CBOR.Decode_All_Result :=
           Dec.Decode_All (Flat, Max_Depth => 1);
      begin
         Check_Status ("depth 1 flat", CBOR.OK, R.Status);
      end;
      --  Strict variant respects Max_Depth
      declare
         R : constant CBOR.Decode_All_Result :=
           Dec.Decode_All_Strict (Depth_8, Max_Depth => 7);
      begin
         Check_Status ("strict depth 7",
                       CBOR.Err_Depth_Exceeded, R.Status);
      end;
   end Test_Max_Depth_Parameter;

   procedure Test_Indef_String_Cumul_Len is
      --  Indefinite byte string: 0x5F + two 3-byte chunks + break
      --  Each chunk is 3 bytes (within a limit of 5), but cumulative
      --  is 6 bytes (exceeds limit of 5).
      Indef_BS : constant Storage_Array :=
        [16#5F#,                              --  indefinite byte string
         16#43#, 16#01#, 16#02#, 16#03#,      --  chunk: 3 bytes
         16#43#, 16#04#, 16#05#, 16#06#,      --  chunk: 3 bytes
         16#FF#];                              --  break
      --  Limit 5: each chunk (3) passes individually but cumulative
      --  (6) should fail
      R_Fail : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (Indef_BS, Max_String_Len => 5);
      --  Limit 6: cumulative exactly at limit, should pass
      R_OK : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (Indef_BS, Max_String_Len => 6);
      --  Limit 100: well above, should pass
      R_OK2 : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (Indef_BS, Max_String_Len => 100);
      --  Same for indefinite text string
      Indef_TS : constant Storage_Array :=
        [16#7F#,                              --  indefinite text string
         16#63#, 16#61#, 16#62#, 16#63#,      --  chunk: "abc" (3 bytes)
         16#62#, 16#64#, 16#65#,              --  chunk: "de" (2 bytes)
         16#FF#];                              --  break
      --  Limit 4: cumulative 5 exceeds limit
      R_TS_Fail : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (Indef_TS, Max_String_Len => 4);
      --  Limit 5: cumulative exactly at limit
      R_TS_OK : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (Indef_TS, Max_String_Len => 5);
   begin
      TIO.Put_Line ("  Indefinite string cumulative length:");
      Check_Status ("indef bs cumul fail",
                    CBOR.Err_String_Too_Long, R_Fail.Status);
      Check_Status ("indef bs cumul ok",
                    CBOR.OK, R_OK.Status);
      Check_Status ("indef bs cumul ok2",
                    CBOR.OK, R_OK2.Status);
      Check_Status ("indef ts cumul fail",
                    CBOR.Err_String_Too_Long, R_TS_Fail.Status);
      Check_Status ("indef ts cumul ok",
                    CBOR.OK, R_TS_OK.Status);
   end Test_Indef_String_Cumul_Len;

   procedure Test_Max_String_Length is
      --  A 5-byte text string
      E : constant Storage_Array :=
        Enc.Encode_Text_String ("hello");
      --  With limit of 10: should pass
      R_OK : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (E, Max_String_Len => 10);
      --  With limit of 4: should fail (string is 5 bytes)
      R_Fail : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (E, Max_String_Len => 4);
      --  Byte string
      BS : constant Storage_Array :=
        Enc.Encode_Byte_String ([16#01#, 16#02#, 16#03#]);
      R_BS_OK : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (BS, Max_String_Len => 3);
      R_BS_Fail : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (BS, Max_String_Len => 2);
      --  Strict variant
      R_Strict : constant CBOR.Decode_All_Result :=
        Dec.Decode_All_Strict (E, Max_String_Len => 4);
   begin
      TIO.Put_Line ("  Max string length:");
      Check_Status ("str limit ok",
                    CBOR.OK, R_OK.Status);
      Check_Status ("str limit fail",
                    CBOR.Err_String_Too_Long, R_Fail.Status);
      Check_Status ("bs limit ok",
                    CBOR.OK, R_BS_OK.Status);
      Check_Status ("bs limit fail",
                    CBOR.Err_String_Too_Long, R_BS_Fail.Status);
      Check_Status ("strict str limit",
                    CBOR.Err_String_Too_Long, R_Strict.Status);
   end Test_Max_String_Length;

   procedure Test_Encode_Text_UTF8 is
      --  Test the new Encode_Text_String_UTF8 function
      UTF8_Bytes : constant Storage_Array :=
        [16#48#, 16#65#, 16#6C#, 16#6C#, 16#6F#];  -- "Hello"
      E : constant Storage_Array :=
        Enc.Encode_Text_String_UTF8 (UTF8_Bytes);
      R : constant CBOR.Decode_Result := Dec.Decode (E);
      D : constant Storage_Array :=
        Dec.Get_String (E, R.Item.TS_Ref);
   begin
      TIO.Put_Line ("  Encode_Text_String_UTF8:");
      Check_Status ("utf8 enc status", CBOR.OK, R.Status);
      Check_Kind ("utf8 enc kind",
                  CBOR.MT_Text_String, R.Item.Kind);
      Check ("utf8 enc len", 5,
             UInt64 (R.Item.TS_Ref.Length));
      Check ("utf8 enc b1", 16#48#, UInt64 (D (1)));
      Check ("utf8 enc b5", 16#6F#, UInt64 (D (5)));
   end Test_Encode_Text_UTF8;

   procedure Test_Reserved_AI is
      --  AI=28 across multiple major types
      R_U28 : constant CBOR.Decode_Result :=
        Dec.Decode ([16#1C#]);          --  MT0 AI=28
      R_U29 : constant CBOR.Decode_Result :=
        Dec.Decode ([16#1D#]);          --  MT0 AI=29
      R_U30 : constant CBOR.Decode_Result :=
        Dec.Decode ([16#1E#]);          --  MT0 AI=30
      R_N29 : constant CBOR.Decode_Result :=
        Dec.Decode ([16#3D#]);          --  MT1 AI=29
      R_B30 : constant CBOR.Decode_Result :=
        Dec.Decode ([16#5E#]);          --  MT2 AI=30
      R_T28 : constant CBOR.Decode_Result :=
        Dec.Decode ([16#7C#]);          --  MT3 AI=28
      R_A29 : constant CBOR.Decode_Result :=
        Dec.Decode ([16#9D#]);          --  MT4 AI=29
      R_M30 : constant CBOR.Decode_Result :=
        Dec.Decode ([16#BE#]);          --  MT5 AI=30
   begin
      TIO.Put_Line ("  Reserved AI values (28-30):");
      Check_Status ("MT0 AI=28", CBOR.Err_Not_Well_Formed,
                    R_U28.Status);
      Check_Status ("MT0 AI=29", CBOR.Err_Not_Well_Formed,
                    R_U29.Status);
      Check_Status ("MT0 AI=30", CBOR.Err_Not_Well_Formed,
                    R_U30.Status);
      Check_Status ("MT1 AI=29", CBOR.Err_Not_Well_Formed,
                    R_N29.Status);
      Check_Status ("MT2 AI=30", CBOR.Err_Not_Well_Formed,
                    R_B30.Status);
      Check_Status ("MT3 AI=28", CBOR.Err_Not_Well_Formed,
                    R_T28.Status);
      Check_Status ("MT4 AI=29", CBOR.Err_Not_Well_Formed,
                    R_A29.Status);
      Check_Status ("MT5 AI=30", CBOR.Err_Not_Well_Formed,
                    R_M30.Status);
   end Test_Reserved_AI;

   procedure Test_Indefinite_Invalid_MT is
      --  Indefinite-length on MT 0, 1, 6 must be rejected
      R_U : constant CBOR.Decode_Result :=
        Dec.Decode ([16#1F#]);          --  MT0 AI=31
      R_N : constant CBOR.Decode_Result :=
        Dec.Decode ([16#3F#]);          --  MT1 AI=31
      R_T : constant CBOR.Decode_Result :=
        Dec.Decode ([16#DF#]);          --  MT6 AI=31
      --  Indefinite on MT 4, 5 should be OK
      R_A : constant CBOR.Decode_Result :=
        Dec.Decode ([16#9F#]);          --  MT4 AI=31 (ok)
      R_M : constant CBOR.Decode_Result :=
        Dec.Decode ([16#BF#]);          --  MT5 AI=31 (ok)
   begin
      TIO.Put_Line ("  Indefinite-length on invalid MTs:");
      Check_Status ("MT0 indef", CBOR.Err_Not_Well_Formed,
                    R_U.Status);
      Check_Status ("MT1 indef", CBOR.Err_Not_Well_Formed,
                    R_N.Status);
      Check_Status ("MT6 indef", CBOR.Err_Not_Well_Formed,
                    R_T.Status);
      Check_Status ("MT4 indef ok", CBOR.OK, R_A.Status);
      Check_Status ("MT5 indef ok", CBOR.OK, R_M.Status);
   end Test_Indefinite_Invalid_MT;

   procedure Test_Empty_Input is
      Empty : constant Storage_Array (0 .. -1) :=
        [others => 0];
      R : constant CBOR.Decode_Result := Dec.Decode (Empty);
      R_All : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (Empty, Check_UTF8 => False);
   begin
      TIO.Put_Line ("  Empty input:");
      Check_Status ("decode empty", CBOR.Err_Truncated,
                    R.Status);
      Check_Status ("decode_all empty", CBOR.Err_Truncated,
                    R_All.Status);
   end Test_Empty_Input;

   procedure Test_Resource_Limit is
      --  A map with count > UInt64'Last / 2 triggers Err_Resource_Limit.
      --  Map count = 2^63 = 0x8000_0000_0000_0000 (exceeds UInt64'Last/2)
      --  Encode: 0xBB (MT5 AI=27) + 8 big-endian bytes
      Huge_Map : constant Storage_Array :=
        [16#BB#,
         16#80#, 16#00#, 16#00#, 16#00#,
         16#00#, 16#00#, 16#00#, 16#00#];
      R : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (Huge_Map, Check_UTF8 => False);
   begin
      TIO.Put_Line ("  Resource limit:");
      Check_Status ("huge map",
                    CBOR.Err_Resource_Limit, R.Status);
   end Test_Resource_Limit;

   procedure Test_Stale_Indef_Str_Len is
      --  Regression: two indefinite byte strings at the same depth.
      --  Second must not carry over cumulative length from first.
      --  Array [_ h'aabb', 0xFF, _ h'ccdd', 0xFF]
      E : constant Storage_Array :=
        [16#82#,                         --  array(2)
         16#5F#,                         --  indefinite byte string
           16#42#, 16#AA#, 16#BB#,       --  chunk: 2 bytes
         16#FF#,                         --  break
         16#5F#,                         --  indefinite byte string
           16#42#, 16#CC#, 16#DD#,       --  chunk: 2 bytes
         16#FF#];                        --  break
      R : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (E, Check_UTF8 => False, Max_String_Len => 3);
      --  Each indef string has cumulative length 2, limit is 3.
      --  Should pass for both (not fail on second due to stale 2+2=4).
   begin
      TIO.Put_Line ("  Stale indef_str_len regression:");
      Check_Status ("two indef bs ok", CBOR.OK, R.Status);
   end Test_Stale_Indef_Str_Len;

   procedure Test_Empty_Indef_Containers is
      --  Minimal empty indefinite containers
      E_Arr : constant Storage_Array :=
        [16#9F#, 16#FF#];              --  [_ ]
      E_Map : constant Storage_Array :=
        [16#BF#, 16#FF#];              --  {_ }
      E_BS  : constant Storage_Array :=
        [16#5F#, 16#FF#];              --  (_ h'')
      E_TS  : constant Storage_Array :=
        [16#7F#, 16#FF#];              --  (_ "")
      R_Arr : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (E_Arr, Check_UTF8 => False);
      R_Map : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (E_Map, Check_UTF8 => False);
      R_BS  : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (E_BS, Check_UTF8 => False);
      R_TS  : constant CBOR.Decode_All_Result :=
        Dec.Decode_All (E_TS, Check_UTF8 => False);
   begin
      TIO.Put_Line ("  Empty indefinite containers:");
      Check_Status ("empty indef arr", CBOR.OK, R_Arr.Status);
      Check_Status ("empty indef map", CBOR.OK, R_Map.Status);
      Check_Status ("empty indef bs", CBOR.OK, R_BS.Status);
      Check_Status ("empty indef ts", CBOR.OK, R_TS.Status);
   end Test_Empty_Indef_Containers;

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

   Test_Indef_String_Cumul_Len;
   Test_Too_Many_Items;
   Test_Nested_Indefinite;
   Test_Decode_Pos_Edge;
   Test_Indef_String_Success;
   Test_TS_With_BS_Chunks;
   Test_Encode_Text_UTF8;
   Test_Encode_Integer;
   Test_Max_Depth_Parameter;
   Test_Max_String_Length;

   Test_Reserved_AI;
   Test_Indefinite_Invalid_MT;
   Test_Empty_Input;
   Test_Resource_Limit;
   Test_Stale_Indef_Str_Len;
   Test_Empty_Indef_Containers;

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
