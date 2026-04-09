--  Copyright (C) 2025 Baris Erdem <baris@erdem.dev>
--  SPDX-License-Identifier: AGPL-3.0-or-later

with Interfaces;

package body CBOR.Decoding is

   pragma SPARK_Mode;

   use Interfaces;

   function Head_Size
     (AI : Unsigned_8)
      return Ada.Streams.Stream_Element_Offset
   is
   begin
      if AI <= 23 then
         return 1;
      elsif AI = 24 then
         return 2;
      elsif AI = 25 then
         return 3;
      elsif AI = 26 then
         return 5;
      elsif AI = 27 then
         return 9;
      else
         return 1;
      end if;
   end Head_Size;

   Max_SE_Length : constant UInt64 :=
     UInt64 (Ada.Streams.Stream_Element_Offset'Last);

   function Is_Shortest
     (AI  : Unsigned_8;
      Val : UInt64)
      return Boolean
   is
   begin
      if AI <= 23 then
         return Val <= 23;
      elsif AI = 24 then
         return Val >= 24 and then Val <= 255;
      elsif AI = 25 then
         return Val >= 256 and then Val <= 65535;
      elsif AI = 26 then
         return Val >= 65536 and then Val <= 16#FFFF_FFFF#;
      elsif AI = 27 then
         return Val >= 16#1_0000_0000#;
      else
         return True;
      end if;
   end Is_Shortest;

   function Has_Head
     (Data : Ada.Streams.Stream_Element_Array;
      Pos  : Ada.Streams.Stream_Element_Offset;
      AI   : Unsigned_8)
      return Boolean
   is
     (Pos in Data'Range
      and then Pos <= Data'Last
      and then (case AI is
                   when 0 .. 23  => True,
                   when 24       => Data'Last - Pos >= 1,
                   when 25       => Data'Last - Pos >= 2,
                   when 26       => Data'Last - Pos >= 4,
                   when 27       => Data'Last - Pos >= 8,
                   when 31       => True,
                   when others   => True))
   with Pre => Data'First >= 0
               and then Data'Last <= Max_Data_Length;

   function Read_Arg
     (Data : Ada.Streams.Stream_Element_Array;
      Pos  : Ada.Streams.Stream_Element_Offset;
      AI   : Unsigned_8)
      return UInt64
     with Pre => Data'First >= 0
                 and then Data'Last <= Max_Data_Length
                 and then Has_Head (Data, Pos, AI)
                 and then (case AI is
                              when 24 =>
                                 Pos <= Ada.Streams
                                   .Stream_Element_Offset'Last - 1,
                              when 25 =>
                                 Pos <= Ada.Streams
                                   .Stream_Element_Offset'Last - 2,
                              when 26 =>
                                 Pos <= Ada.Streams
                                   .Stream_Element_Offset'Last - 4,
                              when 27 =>
                                 Pos <= Ada.Streams
                                   .Stream_Element_Offset'Last - 8,
                              when others =>
                                 True)
   is
   begin
      if AI <= 23 then
         return UInt64 (AI);
      elsif AI = 24 then
         return UInt64 (Unsigned_8 (Data (Pos + 1)));
      elsif AI = 25 then
         return UInt64 (Unsigned_8 (Data (Pos + 1))) * 256
              + UInt64 (Unsigned_8 (Data (Pos + 2)));
      elsif AI = 26 then
         return UInt64 (Unsigned_8 (Data (Pos + 1))) * 16#100_0000#
              + UInt64 (Unsigned_8 (Data (Pos + 2))) * 16#10000#
              + UInt64 (Unsigned_8 (Data (Pos + 3))) * 16#100#
              + UInt64 (Unsigned_8 (Data (Pos + 4)));
      elsif AI = 27 then
         return UInt64 (Unsigned_8 (Data (Pos + 1)))
                  * 16#100_0000_0000_0000#
              + UInt64 (Unsigned_8 (Data (Pos + 2)))
                  * 16#100_0000_0000_00#
              + UInt64 (Unsigned_8 (Data (Pos + 3)))
                  * 16#100_0000_0000#
              + UInt64 (Unsigned_8 (Data (Pos + 4)))
                  * 16#100_0000_00#
              + UInt64 (Unsigned_8 (Data (Pos + 5)))
                  * 16#100_0000#
              + UInt64 (Unsigned_8 (Data (Pos + 6)))
                  * 16#10000#
              + UInt64 (Unsigned_8 (Data (Pos + 7)))
                  * 16#100#
              + UInt64 (Unsigned_8 (Data (Pos + 8)));
      else
         return 0;
      end if;
   end Read_Arg;

   function Decode
     (Data : Ada.Streams.Stream_Element_Array;
      Pos  : Ada.Streams.Stream_Element_Offset := 0)
      return Decode_Result
    is
       P : constant Ada.Streams.Stream_Element_Offset :=
         (if Pos = 0 then Data'First else Pos);
    begin
       if P not in Data'Range then
         return (Status => Err_Truncated,
                 Item    => <>,
                 Offset  => P);
      end if;
      pragma Assert (P in Data'Range);

      declare
         B  : constant Unsigned_8 := Unsigned_8 (Data (P));
         MT : constant CBOR.Major_Type :=
           CBOR.U8_To_MT (Shift_Right (B, 5));
         AI : constant Unsigned_8 := B and 16#1F#;
      begin
         if AI in 28 .. 30 then
            return (Status => Err_Not_Well_Formed,
                    Item    => <>,
                    Offset  => P);
         end if;

         if AI = 31 then
            case MT is
               when CBOR.MT_Unsigned_Integer |
                    CBOR.MT_Negative_Integer |
                    CBOR.MT_Tag =>
                  return (Status => Err_Not_Well_Formed,
                          Item    => <>,
                          Offset  => P);
               when CBOR.MT_Array =>
                  return (Status => OK,
                          Item    => (Kind      => CBOR.MT_Array,
                                      Head_Start => P,
                                      Head_End   => P,
                                      Arr_Count  => UInt64'Last),
                          Offset  => P);
               when CBOR.MT_Map =>
                  return (Status => OK,
                          Item    => (Kind      => CBOR.MT_Map,
                                      Head_Start => P,
                                      Head_End   => P,
                                      Map_Count  => UInt64'Last),
                          Offset  => P);
               when CBOR.MT_Byte_String =>
                  return (Status => OK,
                          Item    => (Kind       => CBOR.MT_Byte_String,
                                      Head_Start => P,
                                      Head_End   => P,
                                      BS_Ref     => CBOR.Null_Ref),
                          Offset  => P);
               when CBOR.MT_Text_String =>
                  return (Status => OK,
                          Item    => (Kind       => CBOR.MT_Text_String,
                                      Head_Start => P,
                                      Head_End   => P,
                                      TS_Ref     => CBOR.Null_Ref),
                          Offset  => P);
             when CBOR.MT_Simple_Value =>
                  return (Status => Err_Not_Well_Formed,
                          Item    => <>,
                          Offset  => P);
             end case;
          end if;

         if not Has_Head (Data, P, AI) then
            return (Status => Err_Truncated,
                    Item    => <>,
                    Offset  => P);
         end if;

          declare
              Head_End : constant Ada.Streams.Stream_Element_Offset :=
                (case AI is
                    when 0 .. 23  => P,
                    when 24       => P + 1,
                    when 25       => P + 2,
                    when 26       => P + 4,
                    when 27       => P + 8,
                    when others   => P);
           begin
            pragma Assert (Head_End in Data'Range);
            case MT is
               when CBOR.MT_Unsigned_Integer =>
                  declare
                     Val : constant UInt64 :=
                       Read_Arg (Data, P, AI);
                  begin
                     if not Is_Shortest (AI, Val) then
                        return (Status => Err_Not_Well_Formed,
                                Item    => <>,
                                Offset  => P);
                     end if;
                     return (Status => OK,
                             Item   => (Kind       =>
                                          CBOR.MT_Unsigned_Integer,
                                        Head_Start => P,
                                        Head_End   => Head_End,
                                        UInt_Value => Val),
                             Offset => Head_End);
                  end;

               when CBOR.MT_Negative_Integer =>
                  declare
                     Val : constant UInt64 :=
                       Read_Arg (Data, P, AI);
                  begin
                     if not Is_Shortest (AI, Val) then
                        return (Status => Err_Not_Well_Formed,
                                Item    => <>,
                                Offset  => P);
                     end if;
                     return (Status => OK,
                             Item   => (Kind       =>
                                          CBOR.MT_Negative_Integer,
                                        Head_Start => P,
                                        Head_End   => Head_End,
                                        NInt_Arg   => Val),
                             Offset => Head_End);
                  end;

               when CBOR.MT_Byte_String =>
                  declare
                     Len : constant UInt64 :=
                       Read_Arg (Data, P, AI);
                  begin
                     if Len > Max_SE_Length then
                        return (Status => Err_Not_Well_Formed,
                                Item    => <>,
                                Offset  => P);
                     end if;
                     if not Is_Shortest (AI, Len) then
                        return (Status => Err_Not_Well_Formed,
                                Item    => <>,
                                Offset  => P);
                     end if;
                     declare
                        SLen : constant Ada.Streams.Stream_Element_Offset :=
                          Ada.Streams.Stream_Element_Offset (Len);
                     begin
                        if SLen > 0
                          and then (Head_End >= Data'Last
                                    or else Data'Last - Head_End < SLen)
                        then
                           return (Status => Err_Truncated,
                                   Item    => <>,
                                   Offset  => P);
                        end if;
                        declare
                           Data_End : constant Ada.Streams
                             .Stream_Element_Offset :=
                             (if SLen = 0 then
                                 Head_End
                              else
                                 Head_End + SLen);
                        begin
                           pragma Assert (Data_End in Data'Range);
                           return (Status => OK,
                                   Item   => (Kind       =>
                                                CBOR.MT_Byte_String,
                                              Head_Start => P,
                                              Head_End   => Data_End,
                                              BS_Ref     =>
                                                (First  => Head_End + 1,
                                                 Length => SLen)),
                                   Offset => Data_End);
                        end;
                     end;
                   end;

                when CBOR.MT_Text_String =>
                   declare
                      Len : constant UInt64 :=
                        Read_Arg (Data, P, AI);
                   begin
                      if Len > Max_SE_Length then
                         return (Status => Err_Not_Well_Formed,
                                 Item    => <>,
                                 Offset  => P);
                      end if;
                      if not Is_Shortest (AI, Len) then
                         return (Status => Err_Not_Well_Formed,
                                 Item    => <>,
                                 Offset  => P);
                      end if;
                     declare
                        SLen : constant Ada.Streams
                          .Stream_Element_Offset :=
                          Ada.Streams.Stream_Element_Offset (Len);
                     begin
                        if SLen > 0
                          and then (Head_End >= Data'Last
                                    or else Data'Last - Head_End < SLen)
                        then
                           return (Status => Err_Truncated,
                                   Item    => <>,
                                   Offset  => P);
                        end if;
                        declare
                           Data_End : constant Ada.Streams
                             .Stream_Element_Offset :=
                             (if SLen = 0 then
                                 Head_End
                              else
                                 Head_End + SLen);
                        begin
                           pragma Assert (Data_End in Data'Range);
                           return (Status => OK,
                                   Item   => (Kind       =>
                                                CBOR.MT_Text_String,
                                              Head_Start => P,
                                              Head_End   => Data_End,
                                              TS_Ref     =>
                                                (First  => Head_End + 1,
                                                 Length => SLen)),
                                   Offset => Data_End);
                        end;
                     end;
                  end;

               when CBOR.MT_Array =>
                  declare
                     Val : constant UInt64 :=
                       Read_Arg (Data, P, AI);
                  begin
                     if not Is_Shortest (AI, Val) then
                        return (Status => Err_Not_Well_Formed,
                                Item    => <>,
                                Offset  => P);
                     end if;
                     return (Status => OK,
                             Item   => (Kind       => CBOR.MT_Array,
                                        Head_Start => P,
                                        Head_End   => Head_End,
                                        Arr_Count  => Val),
                             Offset => Head_End);
                  end;

               when CBOR.MT_Map =>
                  declare
                     Val : constant UInt64 :=
                       Read_Arg (Data, P, AI);
                  begin
                     if not Is_Shortest (AI, Val) then
                        return (Status => Err_Not_Well_Formed,
                                Item    => <>,
                                Offset  => P);
                     end if;
                     return (Status => OK,
                             Item   => (Kind       => CBOR.MT_Map,
                                        Head_Start => P,
                                        Head_End   => Head_End,
                                        Map_Count  => Val),
                             Offset => Head_End);
                  end;

               when CBOR.MT_Tag =>
                  declare
                     Val : constant UInt64 :=
                       Read_Arg (Data, P, AI);
                  begin
                     if not Is_Shortest (AI, Val) then
                        return (Status => Err_Not_Well_Formed,
                                Item    => <>,
                                Offset  => P);
                     end if;
                     return (Status => OK,
                             Item   => (Kind       => CBOR.MT_Tag,
                                        Head_Start => P,
                                        Head_End   => Head_End,
                                        Tag_Number => Val),
                             Offset => Head_End);
                  end;

               when CBOR.MT_Simple_Value =>
                  if AI = 24 then
                     declare
                        SV : constant Unsigned_8 :=
                          Unsigned_8 (Data (P + 1));
                     begin
                        if SV < 32 then
                           return
                             (Status =>
                                Err_Not_Well_Formed,
                              Item    => <>,
                              Offset  => P);
                        end if;
                        return
                          (Status => OK,
                           Item   =>
                             (Kind       =>
                                CBOR.MT_Simple_Value,
                              Head_Start => P,
                              Head_End   => Head_End,
                              SV_Value   => SV,
                              Float_Ref  => CBOR.Null_Ref),
                           Offset => Head_End);
                     end;
                  elsif AI in 25 | 26 | 27 then
                     return
                       (Status => OK,
                        Item   =>
                          (Kind       =>
                             CBOR.MT_Simple_Value,
                           Head_Start => P,
                           Head_End   => Head_End,
                           SV_Value   => AI,
                           Float_Ref  =>
                             (First  => P + 1,
                              Length => (case AI is
                                            when 25 => 2,
                                            when 26 => 4,
                                            when 27 => 8,
                                            when others => 0))),
                        Offset => Head_End);
                  else
                     return
                       (Status => OK,
                        Item   =>
                          (Kind       =>
                             CBOR.MT_Simple_Value,
                           Head_Start => P,
                           Head_End   => Head_End,
                           SV_Value   => AI,
                           Float_Ref  => CBOR.Null_Ref),
                        Offset => Head_End);
                  end if;
            end case;
         end;
      end;
   end Decode;

   function Get_String
     (Data : Ada.Streams.Stream_Element_Array;
      Ref  : String_Ref)
      return Ada.Streams.Stream_Element_Array
   is
      Result : Ada.Streams.Stream_Element_Array
        (1 .. Ref.Length) := (others => 0);
   begin
      for I in 1 .. Ref.Length loop
         pragma Loop_Invariant (I >= 1);
         pragma Loop_Invariant (I <= Ref.Length);
         Result (I) := Data (Ref.First + SE_Offset (I) - 1);
      end loop;
      return Result;
   end Get_String;

   function Is_Valid_UTF8
     (Data : Ada.Streams.Stream_Element_Array)
      return Boolean
   is
      I : Ada.Streams.Stream_Element_Offset := Data'First;
   begin
      while I <= Data'Last loop
         pragma Loop_Variant (Increases => I);
         pragma Loop_Invariant (I >= Data'First);
         pragma Loop_Invariant (I <= Data'Last);
         declare
            B : constant Unsigned_8 := Unsigned_8 (Data (I));
         begin
            if B <= 16#7F# then
               pragma Assert (I < Data'Last
                              or else I = Data'Last);
               I := I + 1;
            elsif B >= 16#C2# and then B <= 16#DF# then
               if Data'Last - I < 1
                 or else Unsigned_8 (Data (I + 1)) not in
                   16#80# .. 16#BF#
               then
                  return False;
               end if;
               pragma Assert (Data'Last - I >= 1);
               pragma Assert (I < Data'Last);
               I := I + 2;
            elsif B = 16#E0# then
               if Data'Last - I < 2
                 or else Unsigned_8 (Data (I + 1)) not in
                   16#A0# .. 16#BF#
                 or else Unsigned_8 (Data (I + 2)) not in
                   16#80# .. 16#BF#
               then
                  return False;
               end if;
               pragma Assert (Data'Last - I >= 2);
               I := I + 3;
            elsif B >= 16#E1# and then B <= 16#EC# then
               if Data'Last - I < 2
                 or else Unsigned_8 (Data (I + 1)) not in
                   16#80# .. 16#BF#
                 or else Unsigned_8 (Data (I + 2)) not in
                   16#80# .. 16#BF#
               then
                  return False;
               end if;
               pragma Assert (Data'Last - I >= 2);
               I := I + 3;
            elsif B = 16#ED# then
               if Data'Last - I < 2
                 or else Unsigned_8 (Data (I + 1)) not in
                   16#80# .. 16#9F#
                  or else Unsigned_8 (Data (I + 2)) not in
                    16#80# .. 16#BF#
               then
                  return False;
               end if;
               pragma Assert (Data'Last - I >= 2);
               I := I + 3;
            elsif B >= 16#EE# and then B <= 16#EF# then
               if Data'Last - I < 2
                 or else Unsigned_8 (Data (I + 1)) not in
                   16#80# .. 16#BF#
                 or else Unsigned_8 (Data (I + 2)) not in
                   16#80# .. 16#BF#
               then
                  return False;
               end if;
               pragma Assert (Data'Last - I >= 2);
               I := I + 3;
            elsif B = 16#F0# then
               if Data'Last - I < 3
                 or else Unsigned_8 (Data (I + 1)) not in
                   16#90# .. 16#BF#
                 or else Unsigned_8 (Data (I + 2)) not in
                   16#80# .. 16#BF#
                 or else Unsigned_8 (Data (I + 3)) not in
                   16#80# .. 16#BF#
               then
                  return False;
               end if;
               pragma Assert (Data'Last - I >= 3);
               I := I + 4;
            elsif B >= 16#F1# and then B <= 16#F3# then
               if Data'Last - I < 3
                 or else Unsigned_8 (Data (I + 1)) not in
                   16#80# .. 16#BF#
                 or else Unsigned_8 (Data (I + 2)) not in
                   16#80# .. 16#BF#
                 or else Unsigned_8 (Data (I + 3)) not in
                   16#80# .. 16#BF#
               then
                  return False;
               end if;
               pragma Assert (Data'Last - I >= 3);
               I := I + 4;
            elsif B = 16#F4# then
               if Data'Last - I < 3
                 or else Unsigned_8 (Data (I + 1)) not in
                   16#80# .. 16#8F#
                 or else Unsigned_8 (Data (I + 2)) not in
                   16#80# .. 16#BF#
                 or else Unsigned_8 (Data (I + 3)) not in
                   16#80# .. 16#BF#
               then
                  return False;
               end if;
               pragma Assert (Data'Last - I >= 3);
               I := I + 4;
            else
               return False;
            end if;
         end;
      end loop;
      return True;
   end Is_Valid_UTF8;

   function Decode_All
     (Data       : Ada.Streams.Stream_Element_Array;
      Check_UTF8 : Boolean := False)
      return Decode_All_Result
   is
      type Container_Kind is (CK_Definite, CK_Indefinite);

      type Stack_Entry is record
         Kind        : Container_Kind := CK_Definite;
         Remaining   : UInt64 := 0;
         Is_Map      : Boolean := False;
         Items_Seen  : UInt64 := 0;
         Parent_MT   : CBOR.Major_Type :=
           CBOR.MT_Unsigned_Integer;
       end record;

       subtype Depth_Count is Natural range 0 .. Max_Nesting_Depth;

       Stack : array (1 .. Max_Nesting_Depth) of Stack_Entry;
       Depth : Depth_Count := 0;

       Result  : Decode_All_Result;
       Pos     : Ada.Streams.Stream_Element_Offset := Data'First;
       Past_End : Boolean := False;

      function Raw_AI
        (Item : CBOR.CBOR_Item)
         return Unsigned_8
      is
         (Unsigned_8 (Data (Item.Head_Start)) and 16#1F#)
      with Pre => Item.Head_Start in Data'Range;

      function Raw_MT
        (Item : CBOR.CBOR_Item)
         return CBOR.Major_Type
      is
         (CBOR.U8_To_MT (Shift_Right
           (Unsigned_8 (Data (Item.Head_Start)), 5)))
      with Pre => Item.Head_Start in Data'Range;

      function Is_Container
        (Item : CBOR.CBOR_Item)
         return Boolean
      is
         (case Raw_MT (Item) is
             when CBOR.MT_Array
                | CBOR.MT_Map
                | CBOR.MT_Tag =>
                True,
             when CBOR.MT_Byte_String
                | CBOR.MT_Text_String =>
                Raw_AI (Item) = 31,
             when others =>
                False)
      with Pre => Item.Head_Start in Data'Range;

      procedure Push
        (CK         : Container_Kind;
         Num_Left   : UInt64;
         Is_A_Map   : Boolean := False;
         Container  : CBOR.Major_Type :=
           CBOR.MT_Unsigned_Integer)
      is
      begin
         if Depth = Max_Nesting_Depth then
            Result.Status := Err_Depth_Exceeded;
            return;
         end if;
         Depth := Depth + 1;
         Stack (Depth) := (CK, Num_Left, Is_A_Map, 0,
                           Container);
      end Push;

      procedure Pop_And_Propagate is
      begin
         while Depth > 0 loop
            pragma Loop_Variant (Decreases => Depth);
            pragma Loop_Invariant (Depth <= Max_Nesting_Depth);
            if Stack (Depth).Kind = CK_Definite then
               if Stack (Depth).Remaining > 0 then
                  Stack (Depth).Remaining :=
                    Stack (Depth).Remaining - 1;
                  Stack (Depth).Items_Seen :=
                    Stack (Depth).Items_Seen + 1;
               end if;
               if Stack (Depth).Remaining = 0 then
                  pragma Assert (Depth > 0);
                  Depth := Depth - 1;
               else
                  exit;
               end if;
            else
               exit;
            end if;
         end loop;
      end Pop_And_Propagate;

      procedure Handle_Container
        (Item : CBOR.CBOR_Item)
      with Pre => Item.Head_Start in Data'Range,
           Post => Result.Count = Result.Count'Old
      is
         AI : constant Unsigned_8 := Raw_AI (Item);
         Max_Map_Entries : constant UInt64 := UInt64'Last / 2;
      begin
         if AI = 31 then
            Push (CK_Indefinite, 0,
                  Is_A_Map  => Item.Kind = CBOR.MT_Map,
                  Container => Item.Kind);
         else
            case Item.Kind is
               when CBOR.MT_Array =>
                  Push (CK_Definite, Item.Arr_Count,
                        Container => Item.Kind);
               when CBOR.MT_Map =>
                  if Item.Map_Count > Max_Map_Entries then
                     Result.Status := Err_Not_Well_Formed;
                     return;
                  end if;
                  Push (CK_Definite, Item.Map_Count * 2,
                        Is_A_Map  => True,
                        Container => Item.Kind);
               when CBOR.MT_Tag =>
                  Push (CK_Definite, 1,
                        Container => Item.Kind);
               when others =>
                  null;
            end case;
         end if;

         if Result.Status /= OK or else Depth = 0 then
            return;
         end if;

         if Depth > 0 then
            if Stack (Depth).Kind = CK_Definite
              and then Stack (Depth).Remaining = 0
            then
               pragma Assert (Depth > 0);
               Depth := Depth - 1;
               Pop_And_Propagate;
            end if;
         end if;
      end Handle_Container;

      procedure Validate_Chunk
        (Item     : CBOR.CBOR_Item;
         Parent   : CBOR.Major_Type;
         Valid    : out Boolean)
      with Pre => Item.Head_Start in Data'Range
      is
         MT : constant CBOR.Major_Type := Item.Kind;
         AI : constant Unsigned_8 :=
           Unsigned_8 (Data (Item.Head_Start)) and 16#1F#;
      begin
         Valid := False;
         if MT /= Parent then
            return;
         end if;
         if AI = 31 then
            return;
         end if;
         Valid := True;
      end Validate_Chunk;

      R : Decode_Result;

   begin
      Result := (Status   => OK,
                 Items    => <>,
                 Count    => 0,
                 Last_Pos => Data'First);

      R := Decode (Data);
      if R.Status /= OK then
         Result.Status := R.Status;
         Result.Last_Pos := Pos;
         return Result;
      end if;

      Result.Count := 1;
      Result.Items (1) := R.Item;
      if R.Offset < Data'Last then
          Pos := R.Offset + 1;
       else
          Pos := R.Offset;
          Past_End := True;
       end if;
      Result.Last_Pos := R.Offset;

      if Check_UTF8
        and then R.Item.Kind = CBOR.MT_Text_String
        and then R.Item.TS_Ref.Length > 0
      then
         declare
            TS : constant Ada.Streams
              .Stream_Element_Array :=
              Get_String (Data, R.Item.TS_Ref);
         begin
            if not Is_Valid_UTF8 (TS) then
               Result.Status := Err_Invalid_UTF8;
               return Result;
            end if;
         end;
      end if;

      if Is_Container (R.Item) then
         Handle_Container (R.Item);
         if Result.Status /= OK then
            return Result;
         end if;
      end if;

      while Depth > 0 and then not Past_End loop
         pragma Loop_Variant
           (Decreases => Max_Decode_Items - Natural (Result.Count));
         pragma Loop_Invariant (Depth <= Max_Nesting_Depth);
         pragma Loop_Invariant (Pos in Data'Range);
         pragma Loop_Invariant (Result.Count in 1 .. Max_Decode_Items);
         pragma Loop_Invariant (Data'First >= 0);
         pragma Loop_Invariant (Data'Last <= Max_Data_Length);

         if Stack (Depth).Kind = CK_Indefinite
           and then Unsigned_8 (Data (Pos)) = 16#FF#
         then
            if Stack (Depth).Is_Map
              and then
                (Stack (Depth).Items_Seen mod 2) = 1
            then
               Result.Status := Err_Not_Well_Formed;
               Result.Last_Pos := Pos;
               return Result;
            end if;
            if Result.Count = Max_Decode_Items then
               Result.Status := Err_Too_Many_Items;
               Result.Last_Pos := Pos;
               return Result;
            end if;
            pragma Assert (Result.Count < Max_Decode_Items);
            Result.Count := Result.Count + 1;
            Result.Items (Result.Count) :=
              (Kind       => CBOR.MT_Simple_Value,
               Head_Start => Pos,
               Head_End   => Pos,
               SV_Value   => 31,
               Float_Ref  => CBOR.Null_Ref);
            Result.Last_Pos := Pos;
            if Pos < Data'Last then
               pragma Assert
                 (Pos < Ada.Streams.Stream_Element_Offset'Last);
               Pos := Pos + 1;
            else
               Past_End := True;
            end if;
            Depth := Depth - 1;
            Pop_And_Propagate;
         else
            R := Decode (Data, Pos);
            if R.Status /= OK then
               Result.Status := R.Status;
               Result.Last_Pos := Pos;
               return Result;
            end if;
            pragma Assert (R.Item.Head_Start in Data'Range);
            pragma Assert (R.Item.Head_End in Data'Range);
            pragma Assert (R.Offset in Data'Range);

            if R.Item.Kind = CBOR.MT_Simple_Value
              and then R.Item.SV_Value = 31
            then
               Result.Status := Err_Not_Well_Formed;
               Result.Last_Pos := Pos;
               return Result;
            end if;

            if Result.Count = Max_Decode_Items then
               Result.Status := Err_Too_Many_Items;
               Result.Last_Pos := Pos;
               return Result;
            end if;
            pragma Assert (Result.Count < Max_Decode_Items);

            declare
               Parent_MT : constant CBOR.Major_Type :=
                 Stack (Depth).Parent_MT;
               Parent_Kind : constant Container_Kind :=
                 Stack (Depth).Kind;
            begin
               if Parent_Kind = CK_Indefinite
                 and then
                   (Parent_MT = CBOR.MT_Byte_String
                    or else Parent_MT = CBOR.MT_Text_String)
               then
                  declare
                     Chunk_OK : Boolean;
                  begin
                     Validate_Chunk
                       (R.Item, Parent_MT, Chunk_OK);
                     if not Chunk_OK then
                        Result.Status := Err_Not_Well_Formed;
                        Result.Last_Pos := Pos;
                        return Result;
                     end if;
                  end;
               end if;

               if Stack (Depth).Is_Map then
                  Stack (Depth).Items_Seen :=
                    Stack (Depth).Items_Seen + 1;
               end if;
            end;

            Result.Count := Result.Count + 1;
            Result.Items (Result.Count) := R.Item;
             if R.Offset < Data'Last then
                pragma Assert
                  (R.Offset < Ada.Streams.Stream_Element_Offset'Last);
                Pos := R.Offset + 1;
             else
                Pos := R.Offset;
                Past_End := True;
             end if;
            Result.Last_Pos := R.Offset;

            if Check_UTF8
              and then R.Item.Kind = CBOR.MT_Text_String
              and then R.Item.TS_Ref.Length > 0
            then
               declare
                  TS : constant Ada.Streams
                    .Stream_Element_Array :=
                    Get_String (Data, R.Item.TS_Ref);
               begin
                  if not Is_Valid_UTF8 (TS) then
                     Result.Status := Err_Invalid_UTF8;
                     return Result;
                  end if;
               end;
            end if;

            if Is_Container (R.Item) then
               Handle_Container (R.Item);
               if Result.Status /= OK then
                  return Result;
               end if;
            else
               Pop_And_Propagate;
            end if;
         end if;
      end loop;

      if Depth > 0 then
         Result.Status := Err_Truncated;
      end if;

      return Result;
   end Decode_All;

end CBOR.Decoding;
