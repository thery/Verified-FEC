From mathcomp Require Import all_ssreflect.
Require Import mathcomp.algebra.matrix.
Require Import mathcomp.algebra.ssralg.
Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.
Set Bullet Behavior "Strict Subproofs".

Require Import Vandermonde.
Require Import Gaussian.
Require Import CommonSSR.

(*TODO: move*)
Lemma index_ord_enum: forall (n: nat), (index_enum (ordinal_finType n)) = ord_enum n.
Proof.
  move => n. have: 0 <= n by []. rewrite leq_eqVlt => /orP[/eqP Hn0 | Hnpos].
  - subst. rewrite /ord_enum /= /index_enum /=. apply size0nil. apply ordinal_enum_size.
  - apply (eq_from_nth (x0:=pred_ord Hnpos)).
    + by rewrite ordinal_enum_size size_ord_enum.
    + move => i. rewrite ordinal_enum_size => Hi.
      have->: i = nat_of_ord (Ordinal Hi) by [].
      by rewrite ordinal_enum nth_ord_enum.
Qed.

Section RS.

(*We prove that the encoder and decoder are correct for any field. We just happen to be using GF(2^n)*)

Variable F : fieldType.

Local Open Scope ring_scope.

(*The encoder takes the last h * k portion (reversed) of the weight matrix and multiplies it by a k * c matrix *)
Definition encoder (h k c max_h max_n : nat) (Hh: h <= max_h) (Hk: k <= max_n) 
  (weights : 'M[F]_(max_h, max_n)) (input : 'M[F]_(k, c)) :=
    (mxsub (fun (x : 'I_h) => widen_ord Hh x) (fun (x : 'I_k) => rev_ord (widen_ord Hk x)) weights) *m input.

Section Decoder.

(*TODO: move (name collision with submx)*)
Definition minusmx {m n} (A B: 'M[F]_(m, n)) := 
  \matrix_(i < m, j < n) (A i j - B i j).

(*Take columns from the end instead of beginning (because the weight matrix is backwards)*)
Definition submx_rows_cols_rev {m n : nat} (m' n': nat) (A: 'M[F]_(m, n)) (rows: seq 'I_m) (cols: seq 'I_n)
  (xm: 'I_m) (xn : 'I_n) := submx_rows_cols m' n' A rows (map (fun x => rev_ord x) cols) xm xn.

(*"Fill in" a matrix with missing data: let D be the original k x c matrix, let R be the recovered data, an 
  xh x c matrix (where xh < k), and let locs be a list of 'I_k of length xh that has the missing locations.
  We want to fill in the locs[n] row of D with row n of R*)
Definition fill_row {k c xh} (D:'M[F]_(k, c)) (R:'M[F]_(xh, c)) (row_d: 'I_k) (row_r : 'I_xh) :=
  \matrix_(i < k, j < c) if i == row_d then R row_r j else D i j.

Definition fill_rows_aux {k c xh} (D:'M[F]_(k, c)) (R:'M[F]_(xh, c)) (locs: seq 'I_k) (xk: 'I_k) (l: seq 'I_xh) :=
  foldl (fun acc x => fill_row acc R (nth xk locs (nat_of_ord x)) x) D l.

Definition fill_rows {k c xh} (D:'M[F]_(k, c)) (R:'M[F]_(xh, c)) (locs: seq 'I_k) (xk: 'I_k) :=
  fill_rows_aux D R locs xk (ord_enum xh).

(*Build dependent type for the next lemma*)
Lemma index_ord_proof: forall {A: eqType} (k: nat) (l: seq A) (x: A),
  x \in l ->
  size l = k ->
  index x l < k.
Proof.
  move => A k l x Hx Hsz. by rewrite -Hsz index_mem.
Qed.

Lemma fill_rows_aux_notin:  forall k c xh (D:'M[F]_(k, c)) (R:'M[F]_(xh, c)) (locs: seq 'I_k) (Hsz: size locs = xh) 
  x y (Hin: x \in locs) (xk: 'I_k) (l: seq 'I_xh),
  uniq locs ->
  (index x locs) \notin (map (@nat_of_ord xh) l) ->
  (fill_rows_aux D R locs xk l) x y = D x y.
Proof.
  move => k c xh D R locs Hsz x y Hxin xk l Hun. move : D. elim : l => [//= |/= h t IH D].
  rewrite in_cons negb_or => /andP[Hnoth Hnott].
  rewrite IH //. rewrite mxE. case Hx: (x == nth xk locs h).
  - apply (elimT eqP) in Hx. rewrite Hx in Hnoth. rewrite index_uniq in Hnoth. by rewrite eq_refl in Hnoth.
    by rewrite Hsz. by [].
  - by [].
Qed.

Lemma fill_rows_aux_spec: forall k c xh (D:'M[F]_(k, c)) (R:'M[F]_(xh, c)) (locs: seq 'I_k) (Hsz: size locs = xh) 
  x y (Hin: x \in locs) (xk: 'I_k) (l: seq 'I_xh),
  uniq locs ->
  uniq l ->
  (index x locs) \in (map (@nat_of_ord xh) l) ->
  (fill_rows_aux D R locs xk l) x y = R (Ordinal (index_ord_proof Hin Hsz)) y.
Proof.
  move => k c xh A R locs Hsz x y Hin xk l Huniq. move: A. elim : l => [//= | /= h t IH A /andP [Hht Hul]].
  rewrite in_cons => /orP[/eqP Hxh | Hxt].
  - subst. rewrite fill_rows_aux_notin //.
    + rewrite mxE. rewrite -Hxh nth_index // eq_refl. f_equal.
      apply ord_inj. by rewrite -Hxh.
    + rewrite Hxh. rewrite mem_map //. apply ord_inj.
  - rewrite IH //.
Qed.

(*We can easily extend this to [fill_rows]*)
Lemma fill_rows_spec:forall k c xh (D:'M[F]_(k, c)) (R:'M[F]_(xh, c)) (locs: seq 'I_k) (Hsz: size locs = xh) 
  x y (Hin: x \in locs) (xk: 'I_k),
  uniq locs ->
  (fill_rows D R locs xk) x y = R (Ordinal (index_ord_proof Hin Hsz)) y.
Proof.
  move => k c xh D R locs Hsz x y Hin xk Huniq.
  apply fill_rows_aux_spec. by []. apply ord_enum_uniq. 
  have Hi: index x locs < xh by apply index_ord_proof.
  have->: index x locs = nat_of_ord (Ordinal Hi) by [].
  rewrite mem_map. apply mem_ord_enum. apply ord_inj.
Qed.

Lemma fill_rows_notin_spec: forall k c xh (D:'M[F]_(k, c)) (R:'M[F]_(xh, c)) (locs: seq 'I_k)
  x y (xk: 'I_k),
  xh <= size locs ->
  x \notin locs ->
  (fill_rows D R locs xk) x y = D x y.
Proof.
  move => k c xh D R locs x y xk Hsz Hnotin.  rewrite /fill_rows. move : D.
  elim : (ord_enum xh) => [//= | h t IH D //=].
  rewrite IH mxE. case Hx:  (x == nth xk locs h) =>[|//=].
  apply (elimT eqP) in Hx. move: Hnotin. rewrite Hx mem_nth //.
  have Hh: h < xh by []. by apply (ltn_leq_trans Hh).
Qed.  

(*What we need to know about this: if we take B = submx_rows_cols' A miss_rows (ord_enum n), and fill the rows of C
  with B according to miss_rows, then C agrees with A on all rows in miss_rows*)
Lemma fill_rows_submx: forall {k c xh} (A C: 'M[F]_(k, c)) (locs: seq 'I_k) (xk: 'I_k) (xc: 'I_c),
  forall (x: 'I_k) (y: 'I_c), size locs = xh -> uniq locs -> x \in locs -> 
    A x y = fill_rows C (submx_rows_cols xh c A locs (ord_enum c) xk xc) locs xk x y.
Proof.
  move => k c xh A C locs xk xc x y Hsz Hun Hin.
  rewrite fill_rows_spec // mxE. f_equal.
  - by rewrite nth_index.
  - by rewrite nth_ord_enum.
Qed.

(*Now we define the decoder*)

Variable k: nat.
Variable c : nat.
Variable max_h : nat.
Variable max_n : nat.
Variable max_size: max_h <= max_n.
Variable k_size: k <= max_n - max_h.
Variable x_max_h : 'I_(max_h).
Variable x_max_n : 'I_(max_n).
Variable x_k : 'I_k.
Variable x_c : 'I_c. 

Variable l : list F.
Variable uniq_l: uniq l.
Variable size_l: size l = max_n.

Lemma k_leq_n: k <= max_n.
Proof.
  apply (leq_trans k_size). by rewrite leq_subr.
Qed.

Definition weights := gaussian_elim (vandermonde max_h max_n l).
(*Definition rev_weight_mx := mxsub (fun x => x) (fun x => rev_ord x) weight_mx.*)

(*Cast a matrix to a square matrix if m = n*)
Definition castmx_square {m n : nat} (Hmn : m = n) (A: 'M[F]_(m, n)) : 'M[F]_n :=
  castmx (Hmn, erefl n) A.

(*Expand ords in a list*)
Definition widen_ord_seq {m n} (Hmn: m <= n) (a: seq 'I_m) : seq 'I_n :=
  map (widen_ord Hmn) a.

(*The input comes in 2 pieces: the k - xh received packets and the xh found parity packets. We will also
  know the xh missing packet locations and the xh found parity packet locations. To represent this in our 
  mathematical model, we will have the decoder take in a full-size matrix (or else the dependent types
  get super annoying), and model the missing packets in the proof *)
(*This is the nice version of the decoder that doesn't do superfluous matrix multiplication. We will
  prove the other version equivalent*)
Definition decoder (h xh: nat) (input: 'M[F]_(k, c)) (parities: 'M[F]_(h, c)) (missing: seq 'I_k) 
  (found_parities : list 'I_(h)) (Hh: h <= max_h) (x_h : 'I_h) : 'M[F]_(k, c) :=
  (*each matrix is named the same as in the C code except that s' is defined by adding the parity vector to s
    (the natural way of decoding)*)
  let w' := invmx (submx_rows_cols_rev xh xh weights (widen_ord_seq Hh found_parities)
              (widen_ord_seq k_leq_n missing) x_max_h x_max_n) in
  let w'' := submx_rows_cols_rev xh (k-xh) weights (widen_ord_seq Hh found_parities) 
             (widen_ord_seq k_leq_n (ord_comp missing)) x_max_h x_max_n in
  let s := w'' *m (submx_rows_cols (k-xh) c input (ord_comp missing) (ord_enum c) x_k x_c) in
  let s' := minusmx (submx_rows_cols xh c parities (found_parities) (ord_enum c) x_h x_c) s in
  let recovered := w' *m s' in
  (*need to build back the original matrix - put recovered in correct positions.*)
  fill_rows input recovered missing x_k.

(*Correctness of decoder: Let data be the original data and input be the input to the decoder.
  If data and input agree on all non-missing packets, and if parities and (encode data) agree
  at all the locations in [found_parities] (ie, the parity packets are valid), then
  decoding the input gives us the original data*)
Theorem decoder_correct: forall h xh (Hh: xh <= h) (data : 'M[F]_(k, c)) (input: 'M[F]_(k, c)) 
  (parities: 'M[F]_(h, c)) (missing_packets : seq 'I_k) (found_parities : seq 'I_h)
  (Hhh: h <= max_h) (x_h : 'I_h),
  (*Only the rows in [missing_packets] are incorrect*)
  (forall (x: 'I_k) (y: 'I_c), x \notin missing_packets -> data x y = input x y) ->
  (*All found parity packets were valid (produced by encoder)*)
  (forall (x: 'I_h) (y: 'I_c), x \in found_parities -> 
    parities x y = (encoder Hhh k_leq_n weights data) x y) ->
  (*We have exactly xh unique missing packets and found parities*)
  uniq missing_packets ->
  uniq found_parities ->
  size missing_packets = xh ->
  size found_parities = xh ->
  (*Then, the decoder recovers the original data*)
  decoder xh input parities missing_packets found_parities Hhh x_h = data.
Proof.
  move => h xh Hxh data input parities missing_packets found_parities Hhh x_h  
  Hnonmissing Hparities Hpackun Hparun Hpacksz Hparsz.
  rewrite /decoder.
  remember (submx_rows_cols_rev xh xh weights (widen_ord_seq Hhh found_parities)
        (widen_ord_seq k_leq_n missing_packets) x_max_h x_max_n) as w'.
  remember (submx_rows_cols_rev xh (k - xh) weights (widen_ord_seq Hhh found_parities)
             (widen_ord_seq k_leq_n (ord_comp missing_packets)) x_max_h x_max_n *m 
              submx_rows_cols (k - xh) c input (ord_comp missing_packets) (ord_enum c) x_k x_c) as s.
  remember (submx_rows_cols xh c parities found_parities (ord_enum c) x_h x_c) as p.
  remember (minusmx p s) as s'.
  (*The key fact we want to prove: S' = (W')^-1 * x*, where x* is the missing data. TODO: maybe separate lemma*)
  have Hsyn: s' = w' *m (submx_rows_cols  xh c data missing_packets (ord_enum c) x_k x_c). {
    (*TODO: use >0 instead of default ords maybe*)
    rewrite Heqs' Heqs Heqp Heqw'. rewrite -matrixP => i j. rewrite !mxE.
    rewrite Hparities. 2 : { apply mem_nth. by rewrite Hparsz. }
    rewrite !mxE. apply /eqP. rewrite GRing.subr_eq. apply /eqP.
    (*idea: we need to split into lost and found indices*) 
    have Hperm: perm_eq (index_enum (ordinal_finType k)) (missing_packets ++ (ord_comp missing_packets)). 
      by rewrite index_ord_enum perm_sym ord_comp_app_perm. 
    rewrite (perm_big _ Hperm) big_cat /=. f_equal.
    - rewrite (big_nth x_k). rewrite (big_nat_widen 0 (size missing_packets) xh). 2: by rewrite Hpacksz leqnn.
      rewrite big_mkord. apply eq_big.
      + move => x. rewrite Hpacksz andTb. by have: x < xh by [].
      + move => x Htriv. rewrite !mxE. f_equal. f_equal. rewrite !(nth_map x_h) //=.
        by rewrite Hparsz. f_equal. rewrite (nth_map x_max_n) //=. f_equal.
        by rewrite (nth_map x_k). by rewrite size_map Hpacksz.
    - rewrite (big_nth x_k). have Hcompsz: (size (ord_comp missing_packets) = k - xh)%N. {
        have: (size (ord_comp missing_packets) + size missing_packets)%N = k
          by rewrite addnC -size_cat ord_comp_cat_size.
        rewrite Hpacksz => Hsz.
        have<-: ((size (ord_comp missing_packets) + xh) - xh)%N = (k - xh)%N by rewrite Hsz.
        rewrite -subnBA. by rewrite subnn subn0. by rewrite leqnn. }
      rewrite (big_nat_widen 0 (size (ord_comp missing_packets)) (k - xh)).
      2: { by rewrite Hcompsz leqnn. }
      rewrite big_mkord. apply eq_big.
      + move => x. rewrite Hcompsz andTb. by have: x < k - xh by [].
      + move => x Htriv. rewrite !mxE. f_equal. f_equal. rewrite !(nth_map x_h) //.
        by rewrite Hparsz. rewrite (nth_map x_max_n). f_equal.
        by rewrite (nth_map x_k). by rewrite size_map Hcompsz.
        apply Hnonmissing.
        have: nth x_k (ord_comp missing_packets) x \in (ord_comp missing_packets). {
          apply mem_nth. by rewrite Hcompsz. }  
        by rewrite in_ord_comp. }
  (*Part 2: w' is invertible*)
  have Hw': w' \in unitmx. rewrite Heqw'. { rewrite /submx_rows_cols_rev /weights.
    have Hmaxh: 0 < max_h by apply ord_nonzero.
    rewrite (@submx_rows_cols_default _ max_h max_n xh xh _ _ _ x_max_h x_max_n (Ordinal Hmaxh) 
      (widen_ord max_size (Ordinal Hmaxh))). apply any_submx_unitmx.
    - by [].
    - by [].
    - rewrite map_inj_uniq //. move => x y. apply widen_ord_inj.
    - rewrite !map_inj_uniq //. move => x y. apply widen_ord_inj. apply rev_ord_inj.
    - by rewrite !size_map Hpacksz Hparsz.
    - by rewrite size_map.
    - move => x. move =>/mapP [y Hy Hxy]. subst.
      move : Hy => /mapP [z Hz Hzy]. subst. rewrite /=.
      have: z < max_n - max_h. have Hz': z < k by []. by apply (ltn_leq_trans Hz').
      rewrite ltn_subCr subnS ltn_pred // subn_gt0. have Hz': z < k by [].
      apply (ltn_leq_trans Hz'). apply k_leq_n.
    - by rewrite size_map Hparsz leqnn.
    - by rewrite !size_map Hpacksz leqnn. }
  (*Part 3: We get the original data back*)
  rewrite Hsyn mulmxA mulVmx // mul1mx. rewrite -matrixP => i j.
  case Hi: (i \in missing_packets).
  - by rewrite -fill_rows_submx.
  - have Hi': i \notin missing_packets by apply negbT. rewrite fill_rows_notin_spec //.
    by rewrite Hnonmissing. by rewrite Hpacksz leqnn.
Qed.

(*TODO: Need version with mx multiplication (in field of char 2), can specialize with positive ordinals,
  prove equivalent to above, maybe make separate correctness thm that is easy corollary*)

(*Probably do a specialized version of field of char 2 and with > 0 params*)
(*
LATER
  GRing.subr_char2: forall [R : ringType], 2 \in [char R] -> forall x y : R, x - y = x + y
*)

End Decoder.

End RS.