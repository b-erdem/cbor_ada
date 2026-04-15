--  Copyright (C) 2025 Baris Erdem <baris@erdem.dev>
--  SPDX-License-Identifier: Apache-2.0
--
--  CBOR library requirements manifest — tracked for SPARK evidence
--  generation. This package is intentionally empty; it exists only
--  to host the @requirement annotations that spark_trace aggregates
--  into a traceability matrix.
--
--  Each requirement is stated in the form expected by spark_trace,
--  i.e. a line comment starting with the tag "at-requirement" followed
--  by a stable identifier and a short title string.
--
--  Requirements are grouped by concern. Identifiers are stable and
--  must not be renumbered — downstream evidence reports key on them.
--
--  ---------------------------------------------------------------
--  Encoder — RFC 8949 Section 3 data model coverage
--  ---------------------------------------------------------------
--
--  @requirement REQ-CBOR-001 "Encoder shall emit valid RFC 8949 major type 0 (unsigned integer) encodings for values in 0 .. 2**64 - 1."
--  @requirement REQ-CBOR-002 "Encoder shall emit valid RFC 8949 major type 1 (negative integer) encodings using the -1 - N convention."
--  @requirement REQ-CBOR-003 "Encoder shall dispatch Integer_64 inputs to the appropriate unsigned or negative major type without loss of range."
--  @requirement REQ-CBOR-004 "Encoder shall emit valid RFC 8949 major type 2 (byte string) definite-length encodings."
--  @requirement REQ-CBOR-005 "Encoder shall emit valid RFC 8949 major type 3 (text string) encodings from pre-validated UTF-8 byte input."
--  @requirement REQ-CBOR-006 "Encoder shall emit valid RFC 8949 major type 4 (array) definite-length headers."
--  @requirement REQ-CBOR-007 "Encoder shall emit valid RFC 8949 major type 5 (map) definite-length headers."
--  @requirement REQ-CBOR-008 "Encoder shall emit valid RFC 8949 major type 6 (tag) headers for the full 64-bit tag number range."
--  @requirement REQ-CBOR-009 "Encoder shall emit RFC 8949 major type 7 simple values, rejecting reserved assignments 24 .. 31."
--  @requirement REQ-CBOR-010 "Encoder shall produce shortest-form head encodings as required by RFC 8949 Section 4.2.1 (deterministic encoding)."
--
--  ---------------------------------------------------------------
--  Decoder — RFC 8949 Section 5 well-formedness validation
--  ---------------------------------------------------------------
--
--  @requirement REQ-CBOR-020 "Decoder shall reject inputs whose declared length exceeds the remaining input buffer (truncated input detection)."
--  @requirement REQ-CBOR-021 "Decoder shall reject non-shortest-form integer argument encodings per RFC 8949 Section 4.2.1."
--  @requirement REQ-CBOR-022 "Decoder shall reject reserved additional-information values 28 .. 30 in the initial byte."
--  @requirement REQ-CBOR-023 "Decoder shall enforce a configurable maximum nesting depth to bound stack usage on untrusted input."
--  @requirement REQ-CBOR-024 "Decoder shall optionally validate text string payloads as RFC 3629 UTF-8, rejecting overlong sequences, surrogates, and code points above U+10FFFF."
--  @requirement REQ-CBOR-025 "Decoder shall reject trailing data after the top-level item when strict mode is requested."
--
--  ---------------------------------------------------------------
--  Round-trip properties — proved as SPARK ghost lemmas
--  ---------------------------------------------------------------
--
--  @requirement REQ-CBOR-040 "Library shall guarantee Decode(Encode_Unsigned(x)) = x for all x in CBOR.UInt64."
--  @requirement REQ-CBOR-041 "Library shall guarantee Decode(Encode_Negative(a)) recovers the negative integer argument a."
--  @requirement REQ-CBOR-042 "Library shall guarantee Decode(Encode_Bool(b)) recovers the original boolean via simple values 20/21."
--  @requirement REQ-CBOR-043 "Library shall guarantee Decode(Encode_Array(n)) recovers the original array item count."
--  @requirement REQ-CBOR-044 "Library shall guarantee Decode(Encode_Tag(t)) recovers the original tag number."
--
--  ---------------------------------------------------------------
--  Cross-cutting / resource safety
--  ---------------------------------------------------------------
--
--  @requirement REQ-CBOR-060 "Library shall be provable at SPARK Level 2 (absence of run-time errors) across the encoder package."
--  @requirement REQ-CBOR-061 "Library shall define a canonical diagnostic notation printer for CBOR items per RFC 8949 Section 8. (Not yet implemented — tracked for traceability gap demonstration.)"

package CBOR.Requirements is

   pragma Pure;

   --  This package intentionally has no declarations. Its sole
   --  purpose is to host the requirement manifest above so that
   --  spark_trace can enumerate every REQ-CBOR-nnn identifier
   --  from a single well-known file.

end CBOR.Requirements;
