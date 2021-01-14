(*Represent Matrices as 2D lists of elements in a field F, indexed by Z. This allows us to deal with all of the
  Ordinal and other dependent type proof obligations here, giving a nicer interface for the VST proofs that uses
  [Znth], [sublist], and Z, and lets us use lia for the resulting goals*)

Require Import VST.floyd.functional_base.

From mathcomp Require Import all_ssreflect.
Require Import mathcomp.algebra.matrix.
Require Import mathcomp.algebra.ssralg.
Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.
Set Bullet Behavior "Strict Subproofs".
Require Import Gaussian.


Lemma sublist_split_Zlength: forall {A} mid (l: list A),
  0 <= mid ->
  Zlength (sublist 0 mid l) + Zlength(sublist mid (Zlength l) l) = Zlength l.
Proof.
  move => A mid l Hmid.
  have [Hin | Hout]: mid <= Zlength l \/ mid > Zlength l by lia.
  - rewrite !Zlength_sublist; lia.
  - rewrite sublist_same_gen; try lia. rewrite sublist_nil_gen; try lia. list_solve.
Qed.

Lemma sublist_same_Zlength: forall {A} mid (l1 l2: list A),
  0 <= mid ->
  Zlength l1 = Zlength l2 ->
  Zlength (sublist 0 mid l1) = Zlength (sublist 0 mid l2).
Proof.
  move => A mid l1 l2 Hmid Hlen. 
  have [Hin | Hout] : mid <= Zlength l1 \/ mid > Zlength l1 by lia.
  - rewrite !Zlength_sublist; lia.
  - rewrite !sublist_same_gen; lia.
Qed.

(*Convert bounded Z to ordinal*)
Lemma Z_nat_bound: forall m x (Hx: 0 <= x < m),
  (Z.to_nat x < Z.to_nat m)%N.
Proof.
  intros m x Hxm. have Hcoqnat: (Z.to_nat x < Z.to_nat m)%coq_nat by apply Z2Nat.inj_lt; lia.
  by apply (introT ltP).
Qed.

Lemma Z_ord_eq: forall {m} (r: Z) (x: 'I_(Z.to_nat m)) (Hr: 0 <= r < m),
  Z.of_nat x = r <-> x == Ordinal (Z_nat_bound Hr).
Proof.
  move => m r x Hr. split => [Hxr | Hord].
  - have Hord: nat_of_ord (Ordinal (Z_nat_bound Hr)) == Z.to_nat r by [].
    have: nat_of_ord (Ordinal (Z_nat_bound Hr)) == Z.to_nat (Z.of_nat x). by rewrite Hxr. by rewrite Nat2Z.id eq_sym.
  - have: x = Ordinal (Z_nat_bound Hr). by apply (elimT eqP). move ->.
    have Hordr: nat_of_ord (Ordinal (Z_nat_bound Hr)) == Z.to_nat r by [].
    have: Z.to_nat (Z.of_nat (Ordinal (Z_nat_bound Hr))) = Z.to_nat r. move : Hordr => /eqP Hordr.
    by rewrite Nat2Z.id. rewrite Nat2Z.id. move ->. by lia.
Qed.

Lemma Z_ord_bound: forall {m} (x : 'I_(Z.to_nat m)),
  0 <= m ->
  0 <= Z.of_nat x < m.
Proof.
  move => m x Hm. have HxmN: (x < Z.to_nat m)%N by [].
  have Hxm_nat : (x < Z.to_nat m)%coq_nat by apply (elimT ltP). by lia.
Qed.

Definition Z_to_ord {m} x (Hx: 0 <= x < m) : 'I_(Z.to_nat m) :=
  Ordinal (Z_nat_bound Hx).

Lemma le_Z_N: forall (m n: Z),
  m <= n ->
  (Z.to_nat m <= Z.to_nat n)%N.
Proof.
  move => m n Hmn. apply (introT leP). lia.
Qed.
  
Section ListMx.

Variable F : fieldType.

Local Open Scope ring_scope.

Instance inhabitant_F: Inhabitant F.
apply 0.
Defined.

Definition matrix := list (list F).

Definition wf_matrix (mx: matrix) (m n : Z) :=
  Zlength mx = m /\ 0 <= n /\ forall x, In x mx -> Zlength x = n.

(*TODO: NOTE: trying without dependent types for VST
Definition matrix m n := {mx : matrix_type | wf_matrix mx m n}.
*)

(*0 matrix - for default in [matrix_of_list] because options will not work well in VST spec*)
(*
Require Import PropList.

Definition zero_mx (m n : Z) : matrix_type :=
  prop_list (fun _ => prop_list (fun _ => 0) (Z.abs n)) (Z.abs m).

Lemma zero_mx_wf: forall m n, wf_matrix (zero_mx m n) (Z.abs m) (Z.abs n).
Proof.
  move => m n. rewrite /wf_matrix /zero_mx. split. apply prop_list_length. lia. split. lia.
  move => x. rewrite In_Znth_iff => [[i [Hilen  Hznth]]]. rewrite -Hznth. rewrite prop_list_Znth.
  apply prop_list_length. lia. move : Hilen. by rewrite prop_list_length; lia.
Qed. 
*)
(*0 matrix*)
(* not good bc of negative inputs
Require Import PropList.

Definition zero_mx (m n : Z) : matrix_type :=
  
  
*)


(*We need a boolean version of this for testing*)
Definition wf_matrix_bool (mx: matrix) (m n : Z) : bool :=
  if Z.eq_dec (Zlength mx) m then 
  if Z_le_lt_dec 0 n then
  if (forallb (fun x => if Z.eq_dec (Zlength x) n then true else false) mx) then true
  else false else false else false.

Lemma wf_bool_wf: forall mx m n,
  wf_matrix_bool mx m n = true <->
  wf_matrix mx m n.
Proof.
  move => mx m n. rewrite /wf_matrix_bool /wf_matrix.
  case : (Z.eq_dec (Zlength mx) m) =>[Hmxlen /= | Hmxlen /=].
  case : (Z_le_lt_dec 0 n) =>[Hn0 /= | Hn0 /=].
  case Hfor : (forallb (fun x : seq F => if proj_sumbool (Z.eq_dec (Zlength x) n) then true else false) mx).
  split. 2: by [].
  move : Hfor; rewrite forallb_forall => Hin H{H}. repeat(split; try by []).
  move => x Hinx. apply Hin in Hinx. move : Hinx. case : (Z.eq_dec (Zlength x) n) =>[Hxn //|//].
  split. by []. move => [Hmx {Hmx} [ Hn {Hn}  Hin]].
  have: (forall x : seq F, In x mx -> (if proj_sumbool (Z.eq_dec (Zlength x) n) then true else false) = true).
  move => x Hinx. case : (Z.eq_dec (Zlength x) n) =>[//|Hneq /=]. by rewrite Hin in Hneq.
  by rewrite -forallb_forall Hfor.
  split. by []. move => [H{H} [Hn0' H{H}]]. lia. split. by []. lia.
Qed.
(*
Lemma wf_bool_to_wf: forall mx m n,
  wf_matrix_bool mx m n = true ->
  wf_matrix mx m n.
Proof.
  move => mx m n. apply wf_bool_wf.
Qed.*)
(*
Definition matrix_of_list (l: matrix_type) (m n : Z) : (matrix (Z.abs m) (Z.abs n)) :=
  match (bool_dec (wf_matrix_bool l (Z.abs m) (Z.abs n)) true) with
  | left H => exist (fun mx => wf_matrix mx (Z.abs m) (Z.abs n)) _ (wf_bool_to_wf H)
  | right H => exist (fun mx => wf_matrix mx (Z.abs m) (Z.abs n)) _ (zero_mx_wf m n)
  end.
*)
(*
Definition matrix_of_list (l: matrix_type) (m n : nat) : (matrix (Z.of_nat m) (Z.of_nat n)).
Admitted.
Lemma wf_matrix_abs: forall mx m n,
  wf_matrix mx m n ->
  wf_matrix mx (Z.abs m) (Z.abs n).
Proof.
  move => mx m n. rewrite /wf_matrix => [[Hlen [Hn0 Hin]]].
  split. list_solve. split. lia. move => x Hinx. rewrite Hin. lia. by [].
Qed. 

Lemma wf_matrix_abs_pos: forall mx m n,
  0 <= m ->
  0 <= n ->
  wf_matrix mx (Z.abs m) (Z.abs n) ->
  wf_matrix mx m n.
Proof.
  move => mx m n Hm Hn. rewrite /wf_matrix => [[Hlen [Hn0 Hin]]].
  split. lia. split. lia. move => x Hinx. rewrite Hin. lia. by [].
Qed.
(*TODO: see what else we need or not about abs
Lemma matrix_abs_prop: forall mx m n (P: forall m n, matrix m n -> Prop),
  0 <= m ->
  0 <= n ->
  

Definition remove_abs: forall mx m n (Hm: 0 <= m) (Hn 
*)
(*
Lemma matrix_of_list_spec: forall mx m n,
  wf_matrix mx m n ->
  proj1_sig (matrix_of_list mx m n) = mx.
Proof.
  move => mx m n. rewrite -wf_bool_wf /matrix_of_list => Hwf.
  case : (bool_dec (wf_matrix_bool mx (Z.abs m) (Z.abs n)) true) => [// | Hcon /=].
  move : Hwf. rewrite wf_bool_wf => Hwf.
  apply wf_matrix_abs in Hwf. by move : Hwf; rewrite -wf_bool_wf => Hwf.
Qed. *)
*)

(*get the (i,j)th entry of a matrix*)
Definition get (mx: matrix) (i j : Z) :=
  let row := Znth i mx in
  Znth j row.



Lemma matrix_m_pos: forall {m n} (mx: matrix) (Hwf: wf_matrix mx m n),
  0 <= m.
Proof.
  move => m n mx. rewrite /wf_matrix => [[Hm Hn]]. list_solve.
Qed.

Lemma matrix_n_pos: forall {m n} (mx: matrix) (Hwf: wf_matrix mx m n),
  0 <= n.
Proof.
  move => m n mx. by rewrite /wf_matrix => [[Hm [Hn Hin]]].
Qed.
(*

Definition get {m n} (mx: matrix m n) (i j : Z) :=
  get_aux (proj1_sig mx) i j.
*)
Definition matrix_to_mx m n (mx: matrix) : 'M[F]_(Z.to_nat m, Z.to_nat n) :=
  \matrix_(i < Z.to_nat m, j < Z.to_nat n) (get mx (Z.of_nat i) (Z.of_nat j)).

(*TODO: maybe need this
Print strong_inv.
Lemma matrix_to_mx_change_dep: forall (m n m' n' : Z) (mx : matrix m n) (mx' : matrix m' n'),
  proj1_sig mx = proj1_sig mx' ->
  matrix_to_mx mx = matrix_to_mx mx'.
*)
(*For the row operations, it will help to define "partial" versions that operate on a sublist, since
  we need need a loop invariant for the operation*)

Section ScMul.

(*Note: we include the conditional so that the result is always a valid matrix, even if r is invalid*)
Definition scalar_mul_row_partial (mx: matrix) (r: Z) (k: F) (bound: Z) : matrix :=
    let old_row := Znth r mx in
    let new_row := map (fun x => k * x) (sublist 0 bound old_row) ++ sublist bound (Zlength old_row) old_row in
    upd_Znth r mx new_row.

Definition scalar_mul_row (mx: matrix) (r: Z) (k: F) : matrix :=
  scalar_mul_row_partial mx r k (Zlength (Znth r mx)).

Lemma scalar_mul_row_partial_wf: forall mx m n r k bound,
  0 <= bound ->
  0 <= r < m ->
  wf_matrix mx m n ->
  wf_matrix (scalar_mul_row_partial mx r k bound) m n.
Proof.
  move => mx m n r k bound Hb Hr. rewrite /wf_matrix /scalar_mul_row_partial => [[Hm [Hn Hin]]].
  split.  by list_solve. split. lia. move => x. rewrite In_Znth_iff => [[i [Hbound Hznth]]].
  have: 0 <= i < m. rewrite Zlength_solver.Zlength_upd_Znth in Hbound.
  by list_solve. move => {} Hbound.
  have [Hir | Hir]: i = r \/ i <> r by lia. subst. rewrite upd_Znth_same => [|//]. 
  rewrite Zlength_app Zlength_map (sublist_split_Zlength _ Hb). apply Hin. by apply Znth_In.
  subst; rewrite upd_Znth_diff; try lia. apply Hin. by apply Znth_In.
Qed.

Lemma scalar_mul_row_spec: forall mx m n r k i j,
  wf_matrix mx m n ->
  (0 <= r < m) ->
  (0 <= i < m) ->
  (0 <= j < n) ->
  get (scalar_mul_row mx r k) i j =
    if (Z.eq_dec i r) then k * (get mx i j) else get mx i j.
Proof.
  move => mx m n r h i j Hwf Hr. rewrite /scalar_mul_row /get /scalar_mul_row_partial sublist_nil 
  cats0 sublist_same => [|//|//]. move : Hwf => [Hm [Hn Hin]].
  case :  (Z.eq_dec i r) => [Hir Hi Hj /= | Hir Hi Hj /=].
  subst.  rewrite upd_Znth_same; try lia. rewrite Znth_map. by [].
  rewrite Hin => [//|]. by apply Znth_In; lia. rewrite upd_Znth_diff => [//|||//]. all: lia.
Qed. 
(*
(*Fold definition into dependent type*)
Definition scalar_mul_row {m n} (mx: matrix m n) (r: Z) (k: F) : matrix m n :=
  exist _ (scalar_mul_row_aux (proj1_sig mx) r k) 
    (scalar_mul_row_aux_wf r k (Zlength_nonneg (Znth r (proj1_sig mx))) (proj2_sig mx)).
*)
(*Prove equivalent to [sc_mul]*)
Lemma scalar_mul_row_equiv: forall {m n} (mx: matrix) r k (Hr: 0 <= r < m),
  wf_matrix mx m n ->
  matrix_to_mx m n (scalar_mul_row mx r k) = sc_mul (matrix_to_mx m n mx) k (Z_to_ord Hr).
Proof.
  move => m n mx r k Hr Hwf. rewrite /matrix_to_mx /scalar_mul_row /sc_mul /Z_to_ord /= -matrixP /eqrel => [x y].
  rewrite !mxE. rewrite (scalar_mul_row_spec k Hwf). 
  - case: (Z.eq_dec (Z.of_nat x) r) => [Hxr /= | Hxr /=].
    have: x == Ordinal (Z_nat_bound Hr) by rewrite -Z_ord_eq. by move ->.
    case Hxord : (x == Ordinal (Z_nat_bound Hr)). have: Z.of_nat x = r. rewrite (Z_ord_eq x Hr). by apply Hxord.
    move => Hxr'. contradiction. by [].
  - by [].
  - apply Z_ord_bound. by lia.
  - apply Z_ord_bound. apply (matrix_n_pos Hwf).
Qed.

End ScMul.

(*Version of [iota] for nonnegative integers - TODO move*)
Definition Ziota (x len : Z) :=
  map (fun y => Z.of_nat y) (iota (Z.to_nat x) (Z.to_nat len)).

Lemma size_length: forall {A : Type} (l: list A),
  size l = Datatypes.length l.
Proof.
  move => A l. elim: l => [//|h t IH /=].
  by rewrite IH.
Qed.

Lemma in_mem_In: forall (l: list nat) x,
  x \in l <-> In x l.
Proof.
  move => l x. elim: l => [//| h t IH /=].
  rewrite in_cons -IH eq_sym. split => [/orP[/eqP Hx | Ht]| [Hx | Hlt]]. by left. by right.
  subst. by rewrite eq_refl. by rewrite Hlt orbT.
Qed.

Lemma Zlength_iota: forall a b,
  Zlength (iota a b) = Z.of_nat b.
Proof.
  move => a b. by rewrite Zlength_correct -size_length size_iota.
Qed.

Lemma Zlength_Ziota: forall x len,
  (0<=x) ->
  (0<= len) ->
  Zlength (Ziota x len) = len.
Proof.
  move => x len Hx Hlen. rewrite /Ziota Zlength_map Zlength_iota. by lia.
Qed.

Lemma Zseq_In: forall x len z,
  (0 <= x) ->
  (0 <= len) ->
  In z (Ziota x len) <-> (x <= z < x + len).
Proof.
  move => x len z Hx Hlen. rewrite /Ziota in_map_iff. split => [[i [Hiz Hin]] | Hb].
  move : Hin; rewrite -in_mem_In mem_iota. move => /andP[Hxi Hixlen].
  have {} Hxi: (Z.to_nat x <= i)%coq_nat by apply (elimT leP).
  have {} Hixlen: (i < Z.to_nat x + Z.to_nat len)%coq_nat by apply (elimT ltP). subst.
  split. lia. rewrite Z2Nat.inj_lt; try lia. by rewrite Nat2Z.id Z2Nat.inj_add; try lia.
  exists (Z.to_nat z). split. rewrite Z2Nat.id; lia. rewrite -in_mem_In mem_iota.
  apply (introT andP). split. by apply (introT leP); lia. apply (introT ltP).
  move : Hb => [Hxz Hzxlen]. move: Hzxlen. rewrite Z2Nat.inj_lt; try lia. by rewrite Z2Nat.inj_add; try lia.
Qed. 

(*Function to make all columns one (repeated scalar multiplication)*)
Section AllColsOne.

Definition all_cols_one_partial (mx: matrix) (c: Z) (bound: Z) :=
  fold_left (fun acc x => scalar_mul_row acc x (get mx x c)^-1 ) (Ziota 0 bound) mx.

Lemma all_cols_one_equiv: forall {m n} (mx: matrix) (c: Z) (Hc: 0 <= c < n),
  wf_matrix mx m n ->
  matrix_to_mx m n (all_cols_one_partial mx c m) = all_cols_one_noif (matrix_to_mx m n mx) (Z_to_ord Hc).
Proof.
  move => m n mx c Hc Hwf. rewrite all_cols_one_noif_foldl /all_cols_one_partial /all_cols_one_noif_l /Ziota /ord_enum.
  have ->: (Z.to_nat 0) = 0%N by lia.
  have: forall n, n \in (iota 0 (Z.to_nat m)) -> (n < Z.to_nat m)%N. move => n'. by rewrite mem_iota.
  remember mx as mx' eqn : Hmx. have Hwf' : wf_matrix mx m n by rewrite -Hmx. 
  rewrite {2}Hmx. rewrite {3}Hmx. move: mx {Hmx} Hwf Hwf'.  
  elim: (iota 0 (Z.to_nat m)) => [//| h t IH mx Hwf Hwf' Hin].
  rewrite /=. have Hbound: (h < Z.to_nat m)%N. apply Hin. by rewrite in_cons eq_refl. rewrite insubT /=.
  have Hhm : 0 <= Z.of_nat h < m. split. lia. have {} Hbound : (h < Z.to_nat m)%coq_nat by apply (elimT ltP).
  lia. rewrite IH.
  - rewrite scalar_mul_row_equiv. f_equal. rewrite /matrix_to_mx mxE.
    have /eqP Hhb: h == Ordinal Hbound by []. rewrite -Hhb.
    have /eqP Hhc : Z.to_nat c == (Z_to_ord Hc) by []. rewrite -Hhc. rewrite Z2Nat.id.
    + f_equal. apply (elimT eqP). have: nat_of_ord (Z_to_ord Hhm) = (Z.to_nat (Z.of_nat h)) by [].
      rewrite Nat2Z.id. move => Hzh. have: nat_of_ord (Z_to_ord Hhm) == nat_of_ord (Ordinal Hbound).
      by rewrite Hzh. by [].
    + lia.
    + by [].
  - by [].
  - apply scalar_mul_row_partial_wf. move : Hwf'; rewrite /wf_matrix => [[Hlen [H0n Hinlen]]].
    rewrite Hinlen. by []. apply Znth_In. lia. by []. by [].
  - move => n' Hinn'. apply Hin. by rewrite in_cons Hinn' orbT.
Qed.

Lemma all_cols_one_partial_wf: forall {m n} mx c bound,
  0 <= bound <= m ->
  wf_matrix mx m n ->
  wf_matrix (all_cols_one_partial mx c bound) m n.
Proof.
  move => m n mx c bound Hb. rewrite /all_cols_one_partial /Ziota.
  have ->: (Z.to_nat 0) = 0%N by lia.
  have: forall n, n \in (iota 0 (Z.to_nat bound)) -> (n < Z.to_nat bound)%N. move => n'. by rewrite mem_iota.
  remember mx as mx' eqn : Hmx. rewrite {1}Hmx {2}Hmx {Hmx}. move : mx.
  elim: (iota 0 (Z.to_nat bound)) => [//| h t IH mx Hin Hwf /=].
  - have Hbound: (h < Z.to_nat bound)%N. apply Hin. by rewrite in_cons eq_refl. 
    have Hhm : 0 <= Z.of_nat h < bound. split. lia. have {} Hbound : (h < Z.to_nat bound)%coq_nat by apply (elimT ltP).
    lia. apply IH.  move => n' Hinn'. apply Hin. by rewrite in_cons Hinn' orbT. apply scalar_mul_row_partial_wf.
    move : Hwf => [Hlen [Hn0 Hinlen]]. rewrite Hinlen =>[//|]. apply Znth_In. list_solve. lia. by [].
Qed. 

End AllColsOne.

(*Combine two lists with a pairwise binary operation - TODO: move probably*)
Fixpoint combine {X Y Z: Type} (l1 : list X) (l2: list Y) (f: X -> Y -> Z) : list Z :=
  match (l1, l2) with
  | (h1 :: t1, h2 :: t2) => f h1 h2 :: combine t1 t2 f
  | (_, _) => nil
  end.

Lemma combine_Zlength: forall {X Y Z} l1 l2 (f : X -> Y -> Z),
  Zlength l1 = Zlength l2 ->
  Zlength (combine l1 l2 f) = Zlength l1.
Proof.
  move => X Y Z l1. elim : l1 => [//| h t IH l2 f /=]. case : l2.
  - by move ->.
  - move => a l. rewrite !Zlength_cons =>[Hlen]. apply Z.succ_inj in Hlen. f_equal. by apply IH.
Qed. 

Lemma combine_Znth: forall {X Y Z} `{Inhabitant X} `{Inhabitant Y} `{Inhabitant Z} l1 l2 (f: X -> Y -> Z) z,
  Zlength l1 = Zlength l2 ->
  0 <= z < Zlength l1 ->
  Znth z (combine l1 l2 f) = f (Znth z l1) (Znth z l2).
Proof.
  move => X Y Z I1 I2 H3 l1. elim: l1 => [l2 f z|h t IH l2 f z]. list_solve.
  case : l2. list_solve. move => h' t' Hlen Hz. rewrite //=.
  have [Hz0 | Hzpos]: (z = 0)%Z \/ 0 < z by lia. subst. list_solve.
  rewrite !Znth_pos_cons; try by []. apply IH; list_solve.
Qed.

Section AddRow.

(*Once again, we only add the first [bound] indices, which will help in the VST proofs*)
Definition add_multiple_partial (mx: matrix) (r1 r2 : Z) (k : F) (bound: Z) : matrix :=
   let new_r2 := combine (sublist 0 bound (Znth r2 mx)) (sublist 0 bound (Znth r1 mx)) (fun x y => x + (k * y)) ++
    sublist bound (Zlength (Znth r2 mx)) (Znth r2 mx) in
  upd_Znth r2 mx new_r2.

Definition add_multiple (mx: matrix) (r1 r2 : Z) (k: F) : matrix :=
  add_multiple_partial mx r1 r2 k (Zlength (Znth r1 mx)).

Lemma add_multiple_partial_wf: forall mx m n r1 r2 k bound,
  0 <= bound ->
  0 <= r1 < m ->
  0 <= r2 < m ->
  wf_matrix mx m n ->
  wf_matrix (add_multiple_partial mx r1 r2 k bound) m n.
Proof.
  move => mx m n r1 r2 k bound Hb Hr1 Hr2. rewrite /wf_matrix /add_multiple_partial /= => [[Hm [Hn Hin]]]. subst.
  split. list_solve. split =>[//| l]. rewrite In_Znth_iff =>[[i [Hlen Hznth]]].
  have {} Hlen: 0 <= i < Zlength mx by list_solve.
  have [Heq | Hneq]: i = r2 \/ i <> r2 by lia. subst.
  rewrite upd_Znth_same => [|//]. rewrite Zlength_app combine_Zlength. rewrite sublist_split_Zlength =>[|//].
  apply Hin. by apply Znth_In; lia. apply sublist_same_Zlength. lia. rewrite !Hin. by [].
  all: try(apply Znth_In; lia). rewrite -Hznth upd_Znth_diff; try lia. apply Hin. by (apply Znth_In; lia).
Qed.

Lemma add_multiple_spec: forall (mx: matrix) m n r1 r2 k i j,
  wf_matrix mx m n ->
  (0 <= r1 < m) ->
  (0 <= r2 < m) ->
  (0 <= i < m) ->
  (0 <= j < n) ->
  get (add_multiple mx r1 r2 k) i j =
    if (Z.eq_dec i r2) then (get mx r2 j) + k * (get mx r1 j)
    else get mx i j.
Proof.
  move => mx m n r1 r2 k i j [Hm [Hn Hin]] Hr1 Hr2. rewrite /add_multiple /add_multiple_partial.
  have Hlen: Zlength (Znth r1 mx) = Zlength (Znth r2 mx). { rewrite !Hin =>[//||]. all: apply Znth_In; lia. }
  rewrite Hlen sublist_nil cats0 !sublist_same; try lia.
  case : (Z.eq_dec i r2) => [Hir2 Hi Hj /=| Hir Hi Hj /=].
  - subst. rewrite /get upd_Znth_same =>[|//]. rewrite combine_Znth =>[//|//|]. rewrite Hin =>[//|].
    by apply Znth_In; lia.
  - by subst; rewrite /get upd_Znth_diff =>[|//|//|//].
Qed.

(*
Definition add_multiple_row {m n} (mx: matrix m n) (r1 r2: Z) (k : F) : matrix m n :=
  exist _ (add_multiple_aux (proj1_sig mx) r1 r2 k) 
    (add_multiple_partial_aux_wf r1 r2 k (Zlength_nonneg (Znth r1 (proj1_sig mx))) (proj2_sig mx)).
*)

(*Equivalence with [add_mul]*)
Lemma add_multiple_row_equiv: forall {m n} (mx: matrix) (r1 r2: Z) (k: F) (Hr1 : 0 <= r1 < m) (Hr2: 0 <= r2 < m),
  wf_matrix mx m n ->
  matrix_to_mx m n (add_multiple mx r1 r2 k) = add_mul (matrix_to_mx m n mx) k (Z_to_ord Hr1) (Z_to_ord Hr2).
Proof.
  move => m n mx r1 r2 k Hr1 Hr2 Hwf. rewrite /matrix_to_mx /add_mul /add_multiple -matrixP /= /eqrel =>[x y].
  rewrite !mxE (add_multiple_spec k Hwf); try lia.
  case : (Z.eq_dec (Z.of_nat x) r2) => [Hxr2 /= | Hxr2 /=].
  have ->: x == Z_to_ord Hr2 by rewrite -Z_ord_eq. by rewrite !Z2Nat.id; try lia.
  case Hxord : (x == Z_to_ord Hr2). have Hcont: Z.of_nat x = r2 by rewrite (Z_ord_eq x Hr2). by [].
  by []. apply Z_ord_bound; lia. apply Z_ord_bound. apply (matrix_n_pos Hwf).
Qed. 

End AddRow.

(*The last intermediate function is the analogue of [sub_all_rows]*)
Section SubRows.

Definition sub_all_rows_partial (mx: matrix) (r: Z) (bound: Z) :=
  fold_left (fun acc x => if Z.eq_dec x r then acc else add_multiple acc r x (- 1)) (Ziota 0 bound) mx.

Lemma sub_all_rows_equiv: forall {m n} (mx: matrix) (r: Z) (Hr: 0 <= r < m),
  wf_matrix mx m n ->
  matrix_to_mx m n (sub_all_rows_partial mx r m) = sub_all_rows_noif (matrix_to_mx m n mx) (Z_to_ord Hr).
Proof.
  move => m n mx r Hr. rewrite sub_all_rows_noif_foldl /sub_all_rows_partial /sub_all_rows_noif_l /Ziota /ord_enum.
  have ->: (Z.to_nat 0) = 0%N by lia.
  have: forall n, n \in (iota 0 (Z.to_nat m)) -> (n < Z.to_nat m)%N. move => n'. by rewrite mem_iota. move : mx.
  elim: (iota 0 (Z.to_nat m)) => [//| h t IH mx Hin Hwf].
  rewrite /=. have Hbound: (h < Z.to_nat m)%N. apply Hin. by rewrite in_cons eq_refl. rewrite insubT /=.
  have Hhm : 0 <= Z.of_nat h < m. split. lia. have Hbound' : (h < Z.to_nat m)%coq_nat by apply (elimT ltP).
  lia. 
  rewrite IH.
  - case : (Z.eq_dec (Z.of_nat h) r) => [Heq /= | Hneq /=].
    + have ->: Ordinal Hbound == Z_to_ord Hr by rewrite -Z_ord_eq. by [].
    + case Hord: (Ordinal Hbound == Z_to_ord Hr). have Heqr: Z.of_nat h = r
      by rewrite (Z_ord_eq (Ordinal Hbound) Hr). by [].
      rewrite add_multiple_row_equiv. f_equal. f_equal. apply (elimT eqP).
      have: nat_of_ord (Z_to_ord Hhm) = (Z.to_nat (Z.of_nat h)) by [].
      rewrite Nat2Z.id. move => Hzh. have: nat_of_ord (Z_to_ord Hhm) == nat_of_ord (Ordinal Hbound).
      by rewrite Hzh. by []. by [].
  - move => n' Hinn'. apply Hin. by rewrite in_cons Hinn' orbT.
  - case : (Z.eq_dec (Z.of_nat h) r) => [// | Hneq /=].
    apply add_multiple_partial_wf; try lia. move: Hwf => [Hlen [H0n Hinlen]].
    rewrite Hinlen. lia. apply Znth_In. lia. by [].
Qed.

Lemma sub_all_rows_partial_wf: forall {m n} mx r bound,
  0 <= bound <= m ->
  0 <= r < m ->
  wf_matrix mx m n ->
  wf_matrix (sub_all_rows_partial mx r bound) m n.
Proof.
  move => m n mx c bound Hb Hr. rewrite /sub_all_rows_partial /Ziota.
  have ->: (Z.to_nat 0) = 0%N by lia.
  have: forall n, n \in (iota 0 (Z.to_nat bound)) -> (n < Z.to_nat bound)%N. move => n'. by rewrite mem_iota.
  move : mx.
  elim: (iota 0 (Z.to_nat bound)) => [//| h t IH mx Hin Hwf /=].
  have Hbound: (h < Z.to_nat bound)%N. apply Hin. by rewrite in_cons eq_refl. 
  have Hhm : 0 <= Z.of_nat h < bound. split. lia. have {} Hbound : (h < Z.to_nat bound)%coq_nat by apply (elimT ltP).
  lia. apply IH. move => n' Hinn'. apply Hin. by rewrite in_cons Hinn' orbT.
  case : (Z.eq_dec (Z.of_nat h) c) => [// | Hneq /=].
  apply add_multiple_partial_wf; try lia. move: Hwf => [Hlen [H0n Hinlen]].
  rewrite Hinlen. lia. apply Znth_In. lia. by [].
Qed.

End SubRows.

Section AllSteps.

Definition gauss_all_steps_rows_partial (mx: matrix) m (bound : Z) :=
  fold_left (fun acc r => let A1 := (all_cols_one_partial acc r m) in sub_all_rows_partial A1 r m) (Ziota 0 bound) mx.

Lemma gauss_all_steps_rows_equiv: forall {m n} (mx: matrix) (Hmn : m <= n),
  wf_matrix mx m n ->
  matrix_to_mx m n (gauss_all_steps_rows_partial mx m m) = gauss_all_steps_restrict_beg (matrix_to_mx m n mx) (le_Z_N Hmn) (Z.to_nat m).
Proof.
  move => m n mx Hmn Hwf. rewrite /gauss_all_steps_rows_partial /gauss_all_steps_restrict_beg /Ziota.
  have ->: (Z.to_nat 0) = 0%N by lia.
  have: forall n, n \in (iota 0 (Z.to_nat m)) -> (n < Z.to_nat m)%N. move => n'. by rewrite mem_iota. move : mx Hwf.
  elim: (iota 0 (Z.to_nat m)) => [//| h t IH mx Hwf Hin].
  rewrite /=. have Hhm: (h < Z.to_nat m)%N. apply Hin. by rewrite in_cons eq_refl.
  have Hhm': 0 <= Z.of_nat h < m. split. lia. 
  have Hbound' : (h < Z.to_nat m)%coq_nat by apply (elimT ltP). lia.
  have Hwf_inter : wf_matrix (all_cols_one_partial mx (Z.of_nat h) m) m n.
  apply all_cols_one_partial_wf. lia. by [].
  rewrite insubT IH /gauss_one_step_restrict. f_equal. 
  rewrite sub_all_rows_equiv. rewrite all_cols_one_equiv. lia. move => Hhn. rewrite /=.
  have ->: (Z_to_ord Hhn) = (widen_ord (le_Z_N Hmn) (Ordinal Hhm)). apply (elimT eqP).
  have : nat_of_ord (Z_to_ord Hhn) == Z.to_nat (Z.of_nat h) by []. by rewrite Nat2Z.id.
  have ->: (Z_to_ord Hhm') = (Ordinal Hhm). apply (elimT eqP). 
  have: nat_of_ord (Z_to_ord Hhm') == Z.to_nat (Z.of_nat h) by []. by rewrite Nat2Z.id. by []. by [].
  by []. apply sub_all_rows_partial_wf. lia. lia. by [].
  move => n' Hnin. apply Hin. by rewrite in_cons Hnin orbT.
Qed.

Lemma gauss_all_steps_rows_partial_wf: forall {m n} (mx: matrix) bound,
  0 <= bound <= m ->
  wf_matrix mx m n ->
  wf_matrix (gauss_all_steps_rows_partial mx m bound) m n.
Proof.
  move => m n mx bound Hb. rewrite /gauss_all_steps_rows_partial /Ziota.
  have ->: (Z.to_nat 0) = 0%N by lia.
  have: forall n, n \in (iota 0 (Z.to_nat bound)) -> (n < Z.to_nat bound)%N. move => n'. by rewrite mem_iota.
  move : mx.
  elim: (iota 0 (Z.to_nat bound)) => [//| h t IH mx Hin Hwf /=].
  have Hbound: (h < Z.to_nat bound)%N. apply Hin. by rewrite in_cons eq_refl. 
  have Hhm : 0 <= Z.of_nat h < bound. split. lia. have {} Hbound : (h < Z.to_nat bound)%coq_nat by apply (elimT ltP).
  lia. apply IH. move => n' Hinn'. apply Hin. by rewrite in_cons Hinn' orbT.
  apply sub_all_rows_partial_wf; try lia. by apply all_cols_one_partial_wf; try lia.
Qed.

End AllSteps.

(*Finally, the last function makes all leading coefficients 1*)

Section LCOne.

Definition all_lc_one_rows_partial (mx: matrix) (bound : Z) :=
  fold_left (fun acc x => scalar_mul_row acc x (get mx x x)^-1) (Ziota 0 bound) mx.

Lemma all_lc_one_rows_equiv: forall {m n} (mx: matrix) (Hmn: m <= n),
  wf_matrix mx m n ->
  matrix_to_mx m n (all_lc_one_rows_partial mx m) = mk_identity (matrix_to_mx m n mx) (le_Z_N Hmn).
Proof.
  move => m n mx Hmn Hwf. rewrite mk_identity_foldl /all_lc_one_rows_partial /mk_identity_l /Ziota /ord_enum.
  have ->: (Z.to_nat 0) = 0%N by lia. remember mx as mx' eqn : Hmx. rewrite {2}Hmx {3}Hmx. 
  have Hwf' : wf_matrix mx m n by rewrite -Hmx. move : Hwf' Hwf.
  have: forall n, n \in (iota 0 (Z.to_nat m)) -> (n < Z.to_nat m)%N. move => n'. by rewrite mem_iota. 
  move : {Hmx} mx. elim : (iota 0 (Z.to_nat m)) => [//|h t IH mx Hin Hwf Hwf'].
  rewrite /=. have Hhm: (h < Z.to_nat m)%N. apply Hin. by rewrite in_cons eq_refl.
  have Hhm': 0 <= Z.of_nat h < m. split. lia. have Hbound' : (h < Z.to_nat m)%coq_nat by apply (elimT ltP). lia.
  rewrite insubT IH /=; try by [].
  rewrite scalar_mul_row_equiv. rewrite {5}/matrix_to_mx mxE. f_equal. f_equal. apply (elimT eqP).
  have: nat_of_ord (Z_to_ord Hhm') == Z.to_nat (Z.of_nat h) by []. by rewrite Nat2Z.id. by [].
  move => n' Hnin. apply Hin. by rewrite in_cons Hnin orbT. apply scalar_mul_row_partial_wf; try lia.
  move : Hwf => [Hlen [H0n Hinlen]]. rewrite Hinlen =>[//|]. apply Znth_In; lia. by [].
Qed.

Lemma all_lc_one_rows_partial_wf: forall {m n} mx bound,
  0 <= bound <= m ->
  wf_matrix mx m n ->
  wf_matrix (all_lc_one_rows_partial mx bound) m n.
Proof.
  move => m n mx bound Hb Hwf. rewrite /all_lc_one_rows_partial /Ziota.
  have ->: (Z.to_nat 0) = 0%N by lia.
  have: forall n, n \in (iota 0 (Z.to_nat bound)) -> (n < Z.to_nat bound)%N. move => n'. by rewrite mem_iota.
  remember mx as mx' eqn : Hmx. move : Hwf. rewrite {3}Hmx {1}Hmx {Hmx}. move : mx.
  elim: (iota 0 (Z.to_nat bound)) => [//| h t IH mx Hwf Hin /=].
  have Hbound: (h < Z.to_nat bound)%N. apply Hin. by rewrite in_cons eq_refl. 
  have Hhm : 0 <= Z.of_nat h < bound. split. lia. have {} Hbound : (h < Z.to_nat bound)%coq_nat by apply (elimT ltP).
  lia. apply IH. apply scalar_mul_row_partial_wf; try lia.
  move : Hwf => [Hlen [Hn0 Hinlen]]. rewrite Hinlen =>[//|]. apply Znth_In. list_solve. by []. 
  move => n' Hinn'. apply Hin. by rewrite in_cons Hinn' orbT.
Qed. 

End LCOne.

Section GaussFull.

Definition gauss_restrict_rows (mx: matrix) m :=
  all_lc_one_rows_partial (gauss_all_steps_rows_partial mx m m) m.

Lemma gauss_restrict_rows_equiv: forall {m n} (mx: matrix) (Hmn: m <= n),
  wf_matrix mx m n ->
  matrix_to_mx m n (gauss_restrict_rows mx m) = gaussian_elim_restrict (matrix_to_mx m n mx) (le_Z_N Hmn).
Proof.
  move => m n mx Hmn Hwf. rewrite /gauss_restrict_rows /gaussian_elim_restrict all_lc_one_rows_equiv.
  rewrite gauss_all_steps_rows_equiv. by rewrite -gauss_all_steps_restrict_both_dirs. by [].
  apply gauss_all_steps_rows_partial_wf. have H0m: 0 <= m by apply (matrix_m_pos Hwf). lia. by [].
Qed.

Lemma gauss_restrict_rows_wf: forall {m n} (mx: matrix),
  wf_matrix mx m n ->
  wf_matrix (gauss_restrict_rows mx m) m n.
Proof.
  move => m n mx Hwf. have H0m: 0 <= m by apply (matrix_m_pos Hwf). apply all_lc_one_rows_partial_wf.
  lia. apply gauss_all_steps_rows_partial_wf. lia. by [].
Qed.

End GaussFull.

(*We need a way to specify that a list matrix m satisfies [strong_inv] without using dependent types*)
Definition strong_inv_list m n (mx: matrix) (r: Z) : Prop :=
  match (range_le_lt_dec 0 r m) with
  | left Hrm =>
      match (Z_le_lt_dec m n) with
      | left H => strong_inv (matrix_to_mx m n mx) (le_Z_N H) (Z_to_ord Hrm)
      | right _ => False
      end
  |right _ => False
  end.

(*TODO: lemma about entries in column here (analogue of [strong_inv_nonzero_cols])*) 

End ListMx.
