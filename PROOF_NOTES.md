# cbor_ada — SPARK proof notes

Lib-local proof-technique notes for `cbor_ada`, indexed from the
workspace [`PROOF_TECHNIQUES.md`](../PROOF_TECHNIQUES.md). Domain tag:
`codec` (binary serialization / deserialization round-trips).

Status (2026-07-07): **1082 / 1082 VCs proved** at
`gnatprove --level=2` (z3 + cvc5) — zero unproved, zero justified,
zero `pragma Assume`, and the 697-case test suite passes with the
executable ghost contracts enabled. All 12
`CBOR.Properties.Lemma_Round_Trip_*` lemmas are closed. The method
that closed them is **§3**; §2 is the pre-closure plan, kept for the
historical record.

---

## 1. Publishing `'First` for unconstrained-array-returning functions

**Domain:** general. **Generalises:** any SPARK function that returns
an unconstrained array (`Storage_Array`, `String`, `Stream_Element_Array`,
a custom `array (Index range <>)`) whose result is later passed to a
callee with an index-range precondition.

### The trap

`CBOR.Encoding.Encode_Unsigned` returns `CBOR.Byte_Array`, which is
`System.Storage_Elements.Storage_Array` — indexed by `Storage_Offset`,
whose base range **includes negatives**. Its original postcondition was:

```ada
function Encode_Unsigned (Value : CBOR.UInt64) return CBOR.Byte_Array
  with Post => Encode_Unsigned'Result'Length in 1 .. 9;
```

`CBOR.Decoding.Decode` requires `Data'First >= 0`. The round-trip lemma
writes `Decode (Encode_Unsigned (V))`. Even though every encoder body
constructs its result as `Storage_Array (1 .. N)` (so `'First` is
*always* 1), the **caller only sees the postcondition**, and the
postcondition publishes `'Length` but says nothing about `'First`.
Across the call boundary `'First` is therefore unknown, and
`Decode`'s precondition `Data'First >= 0` is **unprovable at any
timeout** — it is an information gap in the contract, not a solver
search-depth problem. No amount of `--level=4` / longer `--timeout`
ever closes it.

### The fix

Publish the lower bound in the postcondition:

```ada
function Encode_Unsigned (Value : CBOR.UInt64) return CBOR.Byte_Array
  with Post => Encode_Unsigned'Result'Length in 1 .. 9
               and then Encode_Unsigned'Result'First = 1;   -- <-- added
```

Because the bodies already build `(1 .. N)` arrays, the new conjunct
discharges trivially (no solver search). Applied across all 13
lemma-exercised encoders + the private `Encode_Head` (the head-based
encoders delegate to it, so it must publish `'First` for *their*
postconditions to prove), this closed **20 VCs (83 → 63)** and the
entire `cbor-encoding` unit proves with zero unproved.

### Rule of thumb

> A function returning an unconstrained array must publish **both
> `'First` and `'Length`** in its postcondition if any caller passes
> the result to a routine with an index-range precondition. `'Length`
> alone is a silent dead end.

This is the array-bounds analogue of technique #7 (functional
postconditions to chain bounds): the caller needs to "see through" the
call to the result's index range, not just its size. Prefer pinning
`'First` to a literal over re-sliding the array (a `Storage_Array`
can't be cheaply re-based in SPARK without a copy).

---

## 2. Encode/decode round-trip: the opaque-decoder obstacle (CLOSED — see §3)

**Status: open — the 63 unproved VCs.** This section is the method
plan for the next session, not a solved technique.

### Why `'First` was necessary but not sufficient

Fixing §1 let each integer lemma get *past* the `Decode` precondition
(each moved from "4 of 9" to "6 of 9" checks). But the lemmas still do
not prove. The remaining checks per lemma are the actual round-trip
assertions, e.g. for `Lemma_Round_Trip_Unsigned`:

```ada
R.Status = CBOR.OK
R.Item.Kind = CBOR.MT_Unsigned_Integer
R.Item.UInt_Value = Value
```

These are unprovable because of the **shape of `Decode`'s
postcondition** (cbor-decoding.ads):

```ada
Post => (if Decode'Result.Status = OK then  ... bounds ... )
```

It is *purely conditional on `Status = OK`*. It states nothing about
**when** `Status` is OK, and nothing about `Item.Kind` or the decoded
value. So from the caller's view `Decode` is a black box about its own
success and output: there is no fact available to conclude `Status =
OK`, let alone the decoded value. The single-item `Decode`
(cbor-decoding.adb:471) is a thin wrapper over `Decode_At`
(cbor-decoding.adb:130–469, ~340 lines) which carries all the
major-type / shortest-form / well-formedness logic.

### The method to close it (planned)

Standard verified-serializer round-trip approach — a shared
specification (denotation) function plus a strengthened decoder
contract, in two directions:

1. **Spec/denotation function.** Add a ghost function, e.g.
   `Head_Value (Data) return UInt64` (and a `Head_Major (Data)`),
   giving the abstract meaning of a well-formed head at `Data'First`.
   Specify the *encoder* against it too, so encoder and decoder share
   one model (`Head_Value (Encode_Unsigned (V)) = V` should fall out
   by construction / a small lemma).

2. **Soundness direction** (decode is correct *when* it succeeds):
   strengthen `Decode`/`Decode_At` postcondition with, per major type,
   `if Status = OK and Item.Kind = MT_Unsigned_Integer then
   Item.UInt_Value = Head_Value (Data)`.

3. **Completeness direction** (decode *does* succeed on well-formed
   input): `if <Data is a well-formed shortest-form head> then Status =
   OK and Item.Kind = <major type of Data(Data'First)>`. This is the
   harder half — it requires proving `Decode_At` does not reject valid
   input — and is best done by case analysis over the 5 head
   length-classes (1/2/3/5/9 bytes; see `Head_Size`).

4. **Floats** (`Encode_Float_Half/Single/Double`) additionally need the
   decoder to expose that the raw float bytes are copied through the
   `Float_Ref` slice unchanged (the lemma bodies assert
   `Decoded (i) = B i`). Strictly more work than the integer heads;
   tackle last.

### Feasibility & prior art

Achievable — this is known-shaped work, not a research gamble. The
integer/header lemmas are high-confidence; the float lemmas are
fiddlier; the general functional spec of the *tree* decoder
(`Decode_All`) is **not** required by these lemmas and stays out of
scope. Main cost is iteration time (~7 min per scoped proof cycle on
this machine), dominated by the completeness-direction proofs on
`Decode_At`.

Prior art to cite honestly in any write-up: Microsoft Research's
**EverParse / "Verified CBOR"** (Ramananandro et al., in F\*) already
formally verifies deterministic CBOR for COSE/DICE attestation. So the
contribution here is *not* "first verified CBOR codec." The honest,
narrower claims are: a verified CBOR codec **in SPARK/Ada**, wired into
a **DO-178C / EN 50128 evidence pipeline**, plus the reusable
methodological findings (§1 here, and the round-trip-via-shared-spec
recipe expressed inside SPARK's contract-only discharge model).

### Recommended spike

Prove `Lemma_Round_Trip_Unsigned` end-to-end *first* (one major type,
no floats). It exercises the full method (spec function + both
directions) on the simplest case and yields a template for the other
eight header lemmas before touching floats.

### Spike result (2026-06-20) — soundness is free, completeness has ONE shared blocker

A multi-agent spike implemented and proved the method for the unsigned
case. Outcome: the lemma did **not** fully close, but the path is now
precisely mapped and *verified against the prover*:

- **Soundness generalises for free, and is proven.** A guarded
  conjunct on `Decode`/`Decode_At` —
  `if Item.Kind = MT_Unsigned_Integer then Item.UInt_Value =
  Head_UInt (Data, Item.Head_Start)` — proves on every path with
  **zero regression** to the ~600 green decoder VCs (the guard makes
  the term trivially true on all non-unsigned / error paths). The
  enabling trick: a ghost `Head_UInt` *twin* of the decoder's value
  reader, plus rewriting `Read_Arg` as an **expression function** so
  gnatprove auto-unfolds it and the bridge assert
  `Head_UInt (Data,P) = Read_Arg (Data,P,AI)` discharges. (A regular
  function body does **not** auto-inline — that was the failure that
  made band-splitting the assert *worse*, 71/76.) This pattern
  generalises mechanically to all header types (Negative→`NInt_Arg`,
  Tag→`Tag_Number`, Array→`Arr_Count`, Map→`Map_Count`) via per-type
  `Head_*` twins.

- **Completeness for all 9 header lemmas is blocked by ONE shared root
  cause: the encoder hides its output bytes.** The replay lemma stalls
  on `R.Status = OK` because `Encode_Head`'s postcondition publishes
  only `'Length in 1..9` and `'First = 1` — **not the byte values**
  (head MT-nibble = 0, AI shortest, trailing big-endian bytes present).
  Without those, the decoder cannot be shown to pass its gates and
  reach the OK return on encoder output. This is the **same
  "publish what you produce" lesson as §1, one level deeper**: §1 had
  to publish `'First`; round-trip completeness needs the encoder to
  publish a *functional byte-model* of its result.

**The single remaining hard step** (unlocks completeness for all 9
header lemmas at once): strengthen `Encode_Head`'s postcondition (in
`cbor-encoding.ads`, private section) to publish the head byte and
trailing bytes as a function of `(MT, Val)` — e.g.
`Encode_Head'Result (1) = Make_Head (MT,0) or AI_For (Val)` and the
big-endian trailing bytes equal `Head_UInt`'s band expression — then
re-introduce the per-type magnitude-banded replay lemma. Budget this
against `Encode_Head`'s currently-proven checks. The soundness
conjuncts + `Head_*` twins are cheap and guarded (proven here to not
regress the decoder); the encoder byte-postcondition is the one piece
of real manual proof engineering left.

This is itself the publication-worthy methodological result: **round-trip
closure in SPARK's contract-only model requires the encoder to expose a
functional byte-model in its contract; soundness then comes for free,
and completeness follows by a banded replay lemma.**


---

## 3. Round-trip closure via a shared ghost denotation (2026-07-07)

**Domain:** codec. This is the implemented, prover-verified version of
the plan in §2. All 12 round-trip lemmas prove at `--level=2
--timeout=30` with zero unproved VCs across the library (1082 total).

### Architecture

One new ghost package, `CBOR.Model` (cbor-model.ads), holds the
*denotation* of a CBOR head — pure expression functions only, so
everything unfolds at proof time:

- `Head_AI (Data, P)`, `Head_MT (Data, P)` — bit-level views of the
  head byte;
- `Head_Size (AI)`, `Head_Bytes_Available (Data, P)` — head extent;
- `Head_Value (Data, P)` — the big-endian argument (twin of the
  decoder's `Read_Arg`);
- `Arg_Shortest (AI, Val)` — RFC 8949 §4.2.1 shortest-form (twin of
  the decoder's `Is_Shortest`);
- `Well_Formed_Head (Data, P)` — the exact input class on which the
  decoder is proved to succeed.

Both sides are then specified against the model, and the lemmas
compose **by contract only** — no unfolding of either body at the
lemma site:

- **Encoders** publish `Well_Formed_Head (Result, 1)`,
  `Head_MT (Result, 1) = <their MT>` and
  `Head_Value (Result, 1) = <their argument>` (plus `Head_AI` /
  payload-byte facts for simple values and floats).
- **Decoder** (`Decode`/`Decode_At`) publishes both directions:
  - *completeness* — `(if Well_Formed_Head (Data, P) then
    Result.Status = OK)`;
  - *soundness* — a `Decode_Post_OK` ghost predicate: for definite
    heads (`Head_AI /= 31`) the item's Kind is `Head_MT` and its
    value field equals `Head_Value`, per major type (plus the
    pre-existing bounds facts `Decode_All` consumes).

### The five tricks that made it prove

1. **Twin expression functions.** `Read_Arg`/`Head_Value` and
   `Is_Shortest`/`Arg_Shortest` are byte-for-byte twins; the runtime
   ones were (re)written as expression functions so both unfold and
   the bridge asserts (`Head_Value (Data,P) = Read_Arg (Data,P,AI)`,
   placed once, right after the `Has_Head` gate) discharge by
   congruence. Same for the encoder's `Make_Head`.

2. **Bridge asserts before the case, not in each arm.** Four asserts
   (`Head_AI = AI`, `Head_MT = MT`, `Head_Bytes_Available`,
   `Head_Value = Read_Arg`) after the truncation gate give every
   decoder arm the model view of its local variables.

3. **Completeness ladders on the string-truncation branches.** The
   only two genuinely hard error paths (byte/text string payload
   truncation) needed a 4-step assert ladder ending in
   `not Well_Formed_Head`. Everything else contradicted WF directly.

4. **Stay in one integer domain.** The WF payload clause originally
   compared in `UInt64` (`UInt64 (Data'Last - Item_End) >= Head_Value`)
   and was unprovable at any level — a bitvector/integer bridge. The
   fix: compare in `Storage_Offset` (`... >= SE_Offset (Head_Value)`,
   guarded by the preceding `Head_Value <= SE_Offset'Last` conjunct).
   Same lesson as gnatprove's modular-vs-signed folklore: pick the
   domain of the *body's* comparison.

5. **Quantified bridges for byte-content lemmas.** The float lemmas'
   per-index asserts (`Decoded (6) = B6` …) were flaky at level 2:
   the prover had to chain Get_String's quantified post with the
   encoder's quantified post per index. Two quantified asserts
   (`Encoded (1+I) = Raw (I)` and `Decoded (I) = Encoded (1+I)`)
   made all eight indices instantiate reliably. `Get_String` also
   needed a content post (`Result (I) = Data (Ref.First + I - 1)`)
   and matching loop invariant — it previously published length only.

### One real bug the prover caught

`Bytes'First + I - 1` in the float-encoder posts associates as
`(Bytes'First + I) - 1`, which can overflow `Storage_Offset` because
those encoders bound only `Bytes'Length`, not `Bytes'First`.
Re-parenthesising to `Bytes'First + (I - 1)` closed the last three
VCs. Rule of thumb: in contracts over caller-supplied arrays, write
index arithmetic so every intermediate stays inside the array.

### Cost

Contract-only at the API (no runtime behaviour change; ghost code
compiles away without assertions). VC count grew 724 → 1082; full
library proves in ~6 minutes on this machine, and the per-unit CI
gate (encoding + decoding at level 2 / timeout 30) stays green.
