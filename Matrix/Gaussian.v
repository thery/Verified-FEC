From mathcomp Require Import all_ssreflect.
Require Import mathcomp.algebra.matrix.
Require Import mathcomp.algebra.ssralg.
Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.
Set Bullet Behavior "Strict Subproofs".

Ltac eq_subst H := move : H => /eqP H; subst.

(*Generic helper lemmas*)
Lemma rwN: forall [P: Prop] [b: bool], reflect P b -> ~ P <-> ~~ b.
Proof.
  move => P b Hr. split. by apply introN. by apply elimN.
Qed.

Lemma ltn_total: forall (n1 n2: nat),
  (n1 < n2) || (n1 == n2) || (n2 < n1).
Proof.
  move => n1 n2. case: (orP (leq_total n1 n2)); rewrite leq_eqVlt.
  - move => le_n12; case (orP le_n12) => [Heq | Hlt].  rewrite Heq /=.
    by rewrite orbT orTb. by rewrite Hlt !orTb.
  - move => le_n21; case (orP le_n21) => [Heq | Hlt]. rewrite eq_sym Heq /=.
    by rewrite orbT orTb. by rewrite Hlt !orbT.
Qed. 

Lemma ltn_leq_trans: forall [n m p : nat], m < n -> n <= p -> m < p.
Proof.
  move => m n p Hmn. rewrite leq_eqVlt => /orP[Hmp | Hmp]. eq_subst Hmp. by [].
  move : Hmn Hmp. apply ltn_trans.
Qed.

(*Results about [find] that mostly put the library lemmas into a more convenient form*)

Lemma find_iff: forall {T: eqType} (a: pred T) (s: seq T) (r : nat) (t: T),
  r < size s ->
  find a s = r <-> (forall x, a (nth x s r)) /\ forall x y, y < r -> (a (nth x s y) = false).
Proof.
  move => T a s r t Hsz. split.
  - move => Hfind. subst. split. move => x. apply nth_find. by rewrite has_find.
    move => x. apply before_find.
  - move => [Ha Hbef]. have Hfind := (findP a s). case : Hfind.
    + move => Hhas. have H := (rwN (@hasP T a s)). rewrite Hhas in H.
      have:~ (exists2 x : T, x \in s & a x) by rewrite H. move : H => H{H} Hex.
      have : nth t s r \in s by apply mem_nth. move => Hnthin. 
      have: (exists2 x : T, x \in s & a x) by exists (nth t s r). by [].
    + move => i Hisz Hanth Hprev.
      have Hlt := ltn_total i r. move : Hlt => /orP[H1 | Hgt].
      move : H1 => /orP[Hlt | Heq].
      * have : a (nth t s i) by apply Hanth. by rewrite Hbef.
      * by eq_subst Heq.
      * have : a (nth t s r) by apply Ha. by rewrite Hprev.
Qed.

(*Similar (one direction) for the None case*)
Lemma find_none: forall {T: eqType} (a: pred T) (s: seq T),
  find a s = size s -> (forall x, x \in s -> ~~ (a x)).
Proof.
  move => T a s Hfind. have: ~~ has a s. case Hhas : (has a s). 
  move : Hhas. rewrite has_find Hfind ltnn. by []. by [].
  move => Hhas. by apply (elimT hasPn).
Qed.



Section Gauss.

Variable F : fieldType.

Local Open Scope ring_scope.

(*Preliminaries*)

(*get elements of identity matrix*)
(*TODO:is there a better way to get the field F in there?*)
Lemma id_A : forall {n} (x y : 'I_n),
  (1%:M) x y = if x == y then 1 else (GRing.zero F).
Proof.
move => n x y; rewrite /scalar_mx mxE; by case : (x == y). 
Qed.

(*Working with enums of ordinals*)
Lemma ordinal_enum_size: forall n,
  size (Finite.enum (ordinal_finType n)) = n.
Proof.
  move => n. have: size ([seq val i | i <- enum 'I_n]) = n. rewrite val_enum_ord. by apply: size_iota.
  rewrite size_map. unfold enum. rewrite size_map //.
Qed.

Lemma ordinal_enum: forall {n: nat} (x: 'I_n) y,
  nth y (Finite.enum (ordinal_finType n)) x = x.
Proof.
  move => n x y. have nth_ord := (nth_ord_enum y x). unfold enum in nth_ord. move: nth_ord.
  rewrite (@nth_map _ y) //. by rewrite ordinal_enum_size.
Qed. 

Lemma size_ord_enum: forall n, size (ord_enum n) = n.
Proof.
  move => n. 
  have : size (ord_enum n) = size ([seq val i | i <- ord_enum n]) by rewrite size_map.
  by rewrite val_ord_enum size_iota.
Qed.

Lemma nth_ord_enum: forall n (i: 'I_n) x, nth x (ord_enum n) i = i.
Proof.
  move => n i x. have Hv := val_ord_enum n.  have Hmap :=  @nth_map 'I_n x nat x val i (ord_enum n).
  move : Hmap. rewrite Hv size_ord_enum nth_iota =>[//=|//]. rewrite add0n. move => H.
  (*some annoying stuff about equality of ordinals vs nats*)
  have : nat_of_ord ( nth x (ord_enum n) i) == nat_of_ord i. rewrite {2}H. by []. by [].
  move => Hnatord. have : nth x (ord_enum n) i == i by []. 
  by move => /eqP Heq.
Qed.

(*Some closed form summations we will use*)
Lemma sum_if: forall {n} (x : 'I_n) (f1 : 'I_n -> F),
  \sum_(i < n) (if x == i then f1 i else 0) = f1 x.
Proof.
  move => n x f1. rewrite (big_nth x) /= /index_enum /=. rewrite ordinal_enum_size.
  have Hzero: forall i : nat, i < n -> i != x ->
  (if x == nth x (Finite.enum (ordinal_finType n)) i
    then f1 (nth x (Finite.enum (ordinal_finType n)) i)
    else 0) = 0. {  move => i Hin Hx. have: i == Ordinal Hin by []. move => /eqP Hi; rewrite Hi.
   rewrite ordinal_enum. have: (Ordinal Hin != x) by [].
   rewrite /negb. rewrite eq_sym. by case(x == Ordinal Hin). }
  rewrite (@big_cat_nat _ _ _ x) /= => [| // | ]. 2: by apply: ltnW.
  rewrite big_nat_cond big1.
  - rewrite big_ltn => [|//]. rewrite big_nat_cond big1.
    + by rewrite ordinal_enum eq_refl GRing.add0r GRing.addr0.
    + move => i /andP[/andP [Hxi Hin]]. move => H{H}. apply Hzero. by []. by rewrite gtn_eqF.
  - move => i /andP[/andP [Hxi Hin]]. move => H{H}. apply Hzero. have: x < n by []. move : Hin.
    apply ltn_trans. by rewrite ltn_eqF.
Qed.

Lemma sum_if_twice: forall {n} (r1 r2 : 'I_n) (f1 f2 : 'I_n -> F),
  r1 < r2 ->
  \sum_(i < n) (if i == r1 then f1 i else if i == r2 then f2 i else 0) = f1 r1 + f2 r2.
Proof.
move => n r1 r2 f1 f2 Hlt. rewrite (big_nth r1) /= /index_enum /= ordinal_enum_size.
  have Hzero: forall i : nat, i < n -> i != r1 -> i != r2 ->
  (if nth r1 (Finite.enum (ordinal_finType n)) i == r1
  then f1 (nth r1 (Finite.enum (ordinal_finType n)) i)
  else
  if nth r1 (Finite.enum (ordinal_finType n)) i == r2
  then f2 (nth r1 (Finite.enum (ordinal_finType n)) i)
  else 0) = 0. {
  move => i Hin Hir1 Hr2. have: i == Ordinal Hin by []. move => /eqP Hi. rewrite Hi. 
  rewrite ordinal_enum.
  have: (Ordinal Hin != r1) by []. have: (Ordinal Hin != r2) by []. rewrite /negb.  case(Ordinal Hin == r2).
  by []. by case (Ordinal Hin == r1). } 
  rewrite (@big_cat_nat _ _ _ r1) /=. 2 : by []. 2 : by [apply: ltnW].
  rewrite big_nat_cond big1. 
  - rewrite big_ltn. 2: by [].
    rewrite ordinal_enum eq_refl GRing.add0r (@big_cat_nat _ _ _ r2) /=. 2 : by []. 2 : by [apply: ltnW].
    rewrite big_nat_cond big1.
    + rewrite big_ltn. 2: by []. rewrite ordinal_enum.
      have: (r2 == r1 = false) by apply gtn_eqF. move => Hneq; rewrite Hneq {Hneq}.
      rewrite eq_refl GRing.add0r big_nat_cond big1. by rewrite GRing.addr0.
      move => i /andP[/andP [H0i Hix]]. move =>H {H}. 
      apply: Hzero. by []. rewrite gtn_eqF. by []. move : Hlt H0i. apply ltn_trans. by rewrite gtn_eqF.
    + move => i /andP[/andP [H0i Hix]]. move =>H {H}. apply: Hzero. have: r2 < n by []. move : Hix.
      apply ltn_trans. by rewrite gtn_eqF. by rewrite ltn_eqF.
  - move => i /andP[/andP [H0i Hix]]. move =>H {H}. apply: Hzero. have: r1 < n by []. move : Hix.
    apply ltn_trans. by rewrite ltn_eqF. rewrite ltn_eqF //. move : Hix Hlt. apply ltn_trans.
Qed.


(** Elementary Row Operations*)

(*Swapping rows is already defined by mathcomp - it is xrow. We just need the following*)
Lemma xrow_val: forall {m n} (A: 'M[F]_(m,n)) (r1 r2 : 'I_m) x y,
  (xrow r1 r2 A) x y = if x == r1 then A r2 y else if x == r2 then A r1 y else A x y.
Proof. 
  rewrite /xrow /row_perm //= => m n A r1 r2 x y. rewrite mxE.
  case Hxr1 : (x == r1). eq_subst Hxr1. by rewrite perm.tpermL.
  case Hxr2 : (x == r2). eq_subst Hxr2. by rewrite perm.tpermR.
  rewrite perm.tpermD. by []. by rewrite eq_sym Hxr1. by rewrite eq_sym Hxr2.
Qed. 

(*scalar multiply row r in matrix A by scalar c*)
Definition sc_mul {m n} (A : 'M[F]_(m, n)) (c: F) (r: 'I_m) : 'M[F]_(m, n) :=
  \matrix_(i < m, j < n) if i == r then c * (A i j) else A i j. 

(*elementary matrix for scalar multiplication*)
Definition sc_mul_mx (n: nat) (c: F) r : 'M[F]_(n, n) := @sc_mul n n (1%:M) c r.

(*scalar multiplication is same as mutliplying by sc_mul_mx on left*)
Lemma sc_mulE: forall {m n : nat} (A: 'M[F]_(m, n)) (c: F) (r: 'I_m),
  sc_mul A c r = (sc_mul_mx c r) *m A.
Proof.
move => m n A c r; rewrite /sc_mul_mx /sc_mul. rewrite -matrixP /eqrel => x y. rewrite !mxE /=. erewrite eq_big_seq.
2 : { move => z. rewrite mxE id_A //. }
rewrite /=. case : (eq_op x r). 
  - erewrite eq_big_seq. 2 : { move => z Inz. rewrite -GRing.mulrA //. }
    rewrite (@eq_big_seq _ _ _ _ _ _ (fun z => c * ((if x == z then A z y else 0)))).
    rewrite -big_distrr. by rewrite sum_if. rewrite //= /eqfun. move => x' Xin.
    case(x == x'). by rewrite GRing.mul1r. by rewrite GRing.mul0r.
  - rewrite (@eq_big_seq _ _ _ _ _ _ (fun z => ((if x == z then A z y else 0)))).
    by rewrite sum_if. rewrite /eqfun //= => x' Xin. case (x == x').
    by rewrite GRing.mul1r. by rewrite GRing.mul0r.
Qed.

(*inverse for scalar sc_mul_mx*)
Lemma sc_mul_mx_inv: forall {m : nat} (c: F) (r: 'I_m),
  c != 0 ->
  (sc_mul_mx c r) *m (sc_mul_mx c^-1 r) = 1%:M.
Proof.
  move => m c r Hc. rewrite -sc_mulE. rewrite !/sc_mul_mx /sc_mul.
  rewrite -matrixP /eqrel => x y. rewrite !mxE. case Heq: ( x == r). 
  rewrite GRing.mulrA. rewrite GRing.divff. by rewrite GRing.mul1r. by []. by [].
Qed.

(*sc_mul_mx is invertible*)
Lemma sc_mul_mx_unitmx: forall {m : nat} (c: F) (r: 'I_m),
  c != 0 ->
  (sc_mul_mx c r) \in unitmx.
Proof.
  move => m c r Hc. apply: (proj1 (mulmx1_unit (@sc_mul_mx_inv m c r  Hc))).
Qed. 

(*Add multiple of one row to another - r2 := r2 + c * r1*)
Definition add_mul {m n} (A : 'M[F]_(m, n)) (c: F) (r1 r2: 'I_m) : 'M[F]_(m, n) :=
  \matrix_(i < m, j < n) if i == r2 then (A r2 j) + (c * (A r1 j)) else A i j. 

(*elementary matrix for adding multiples*)
Definition add_mul_mx (n: nat) (c: F) r1 r2 : 'M[F]_(n,n) := 
  \matrix_(i < n, j < n) if i == r2 then 
                            if j == r1 then c else if j == r2 then 1 else 0
                         else if i == j then 1 else 0.


(*adding multiple is the same as multiplying by [add_mul_mx] matrix on left *)
Lemma add_mulE: forall {m n : nat} (A: 'M[F]_(m, n)) (c: F) (r1 r2: 'I_m),
  r1 != r2 ->
  add_mul A c r1 r2 = (add_mul_mx c r1 r2) *m A.
Proof.
move => m n A c r1 r2 Hr12; rewrite /add_mul_mx /add_mul. rewrite -matrixP /eqrel => x y. rewrite !mxE /=.
erewrite eq_big_seq. 2 : { move => z. rewrite mxE //. } rewrite //=.
case : (eq_op x r2). 
  - rewrite (@eq_big_seq _ _ _ _ _ _ (fun z => ((if z == r1 then c * A z y else if z == r2 then A z y else 0)))).
    case (orP (ltn_total r1 r2)) => [Hleq | Hgt].
    + case (orP Hleq) => [Hlt | Heq]. rewrite sum_if_twice //. by rewrite GRing.addrC.
      have: (nat_of_ord r1 != nat_of_ord r2) by [].
      rewrite /negb. by rewrite Heq.
    + rewrite (@eq_big_seq _ _ _ _ _ _ (fun z => ((if z == r2 then A z y else if z == r1 then c * A z y else 0)))).
      rewrite sum_if_twice //. move => z Hz. case Hzr1 : (z == r1). eq_subst Hzr1. 
      case Hzr2 : (r1 == r2). eq_subst Hzr2. by rewrite ltnn in Hgt. by []. by [].
    + move => z Hz. case Hzeq : (z == r1). by []. case Hze: (z == r2).  by apply GRing.mul1r. by apply GRing.mul0r.
  - rewrite (@eq_big_seq _ _ _ _ _ _ (fun z => (if x == z then A z y else 0))). by rewrite sum_if.
    move => z Hz. case Heqz : (x == z). by apply GRing.mul1r. by apply GRing.mul0r.
Qed.

Lemma add_mul_mx_inv: forall {m : nat} (c: F) (r1 r2: 'I_m),
  r1 != r2 ->
  (add_mul_mx c r1 r2) *m (add_mul_mx (- c) r1 r2) = 1%:M.
Proof.
  move => m c r1 r2 Hr12. rewrite -add_mulE //. rewrite !/add_mul_mx /add_mul.
  rewrite -matrixP /eqrel => x y. rewrite !mxE eq_refl. have: r1 == r2 = false. move : Hr12. rewrite /negb.
  by case (r1 == r2). move ->. case Hxr2 : (x == r2). eq_subst Hxr2. 
  rewrite eq_sym. case Hyr1 : (r1 == y). eq_subst Hyr1. 
  rewrite GRing.mulr1 GRing.addNr eq_sym. move : Hr12. rewrite /negb. by case H : (y == r2).
  rewrite eq_sym GRing.mulr0 GRing.addr0. by case H : (r2 == y). by case H : (x == y).
Qed.

(*add_mul_mx is invertible*)
Lemma add_mul_mx_unitmx: forall {m : nat} (c: F) (r1 r2: 'I_m),
  r1 != r2 ->
  (add_mul_mx c r1 r2) \in unitmx.
Proof.
  move => m c r1 r2 Hr12. apply: (proj1 (mulmx1_unit (@add_mul_mx_inv m c r1 r2 Hr12))).
Qed.

(** Row equivalence *)

Inductive ero : forall (m n : nat), 'M[F]_(m, n) -> 'M[F]_(m, n) -> Prop :=
  | ero_swap: forall {m n} r1 r2 (A : 'M[F]_(m,n)),
      ero A (xrow r1 r2 A)
  | ero_sc_mul: forall {m n} r c (A : 'M[F]_(m,n)),
      c != 0 ->
      ero A (sc_mul A c r)
  | ero_add_mul: forall {m n} r1 r2 c (A : 'M[F]_(m,n)),
      r1 != r2 ->
      ero A (add_mul A c r1 r2).

Lemma ero_mul_unit: forall {m n} (A B : 'M[F]_(m, n)),
  ero A B ->
  exists E, (E \in unitmx) && (B == E *m A).
Proof.
  move => m n A B Hero. elim: Hero; move => m' n' r1.
  - move => r2 A'. exists (tperm_mx r1 r2). by rewrite {1}/tperm_mx unitmx_perm xrowE eq_refl.
  - move => c A' Hc. exists (sc_mul_mx c r1). by rewrite sc_mulE eq_refl sc_mul_mx_unitmx.
  - move => r2 c A' Hr. exists (add_mul_mx c r1 r2). rewrite add_mulE. by rewrite eq_refl add_mul_mx_unitmx. by [].
Qed.

Inductive row_equivalent: forall m n, 'M[F]_(m, n) -> 'M[F]_(m, n) -> Prop :=
  | row_equiv_refl: forall {m n} (A: 'M[F]_(m,n)),
     row_equivalent A A
  | row_equiv_ero: forall {m n} (A B C: 'M[F]_(m,n)),
     ero A B ->
     row_equivalent B C ->
     row_equivalent A C.

Lemma ero_row_equiv: forall {m n} (A B : 'M[F]_(m,n)),
  ero A B ->
  row_equivalent A B.
Proof.
  move => m n A B Hero. apply (@row_equiv_ero _ _ _ B) => [//|]. apply row_equiv_refl.
Qed.

Lemma row_equivalent_trans: forall {m n} (A B C : 'M[F]_(m, n)),
  row_equivalent A B ->
  row_equivalent B C ->
  row_equivalent A C.
Proof.
  move => m n A B C Hre. move : C. elim: Hre; clear m n A B.
  - by [].
  - move => m n A B C Hero Hre IH D Hd. apply (@row_equiv_ero _ _ A B D). by []. by apply: IH.
Qed. 

(*If A and B are row equivalent, then A = EB for some invertible matrix E*) 
Lemma row_equivalent_mul_unit: forall {m n} (A B : 'M[F]_(m, n)),
  row_equivalent A B ->
  exists E, (E \in unitmx) && (B == E *m A).
Proof.
  move => m n A B Hre. elim: Hre; clear m n A B; move => m n A.
  - exists (1%:M). by rewrite unitmx1 mul1mx eq_refl.
  - move => B C Hero Hre IH. case : IH. move => E /andP[Heu /eqP Hc].
    apply ero_mul_unit in Hero. case: Hero. move => E' /andP[Heu' /eqP Hb]. subst. 
    exists (E *m E'). rewrite unitmx_mul.
    by rewrite mulmxA eq_refl Heu Heu'. 
Qed.

(*If A and B are row equivalent, then A is invertible iff B is*)
Lemma row_equivalent_unitmx_iff: forall {n} (A B : 'M[F]_(n, n)),
  row_equivalent A B ->
  (A \in unitmx) = (B \in unitmx).
Proof.
  move => n A B Hre. apply row_equivalent_mul_unit in Hre. case Hre => E /andP[Hunit /eqP Hb]. 
  by rewrite Hb unitmx_mul Hunit. 
Qed. 

(** Gaussian Elimination*)
(*Find the first nonzero entry in column col, starting from index r*)
(*Because we want to use the result to index into a matrix, we need an ordinal. So we have a function that
  returns the nat, then we wrap the type in an option. This makes the proofs a bit more complicated*)

Definition fst_nonzero_nat {m n} (A: 'M[F]_(m, n)) (col: 'I_n) (r: 'I_m) : nat :=
  (find (fun (x : 'I_m) => (r <= x) && (A x col != 0)) (ord_enum m)).

Definition fst_nonzero {m n} (A: 'M[F]_(m, n)) (col: 'I_n) (r: 'I_m) : option 'I_m :=
  insub (fst_nonzero_nat A col r).

Lemma fst_nonzero_nat_bound:  forall {m n} (A: 'M[F]_(m, n)) (col: 'I_n) (r: 'I_m),
  (fst_nonzero_nat A col r == m) || (fst_nonzero_nat A col r < m).
Proof.
  move => m n A col r. rewrite /fst_nonzero_nat.
  have Hleq := find_size(fun x : 'I_m => (r <= x) && (A x col != 0)) (ord_enum m). move : Hleq.
  by rewrite size_ord_enum leq_eqVlt.
Qed.  

(*Specification of some case of [find_nonzero]*)
Lemma fst_nonzero_some_iff: forall {m n} (A: 'M[F]_(m, n)) (col: 'I_n) (r: 'I_m) f,
  fst_nonzero A col r = Some f <-> (r <= f) /\ (A f col != 0) /\ (forall (x : 'I_m), r <= x < f -> A x col == 0).
Proof.
  move => m n A col r f.
  have: r <= f /\ A f col != 0 /\ (forall x : 'I_m, r <= x < f -> A x col == 0) <-> fst_nonzero_nat A col r = f.
  rewrite /fst_nonzero_nat. rewrite find_iff.
  - split. move => [Hrf [Hnonz Hbef]]. split. move => x. by rewrite nth_ord_enum Hrf Hnonz.
    move => x y Hyf. have Hym : y < m. have : f < m by []. move : Hyf. by apply ltn_trans.
    have: nth x (ord_enum m) y = nth x (ord_enum m) (Ordinal Hym) by [].
    move ->. rewrite nth_ord_enum. case Hr : (r <= Ordinal Hym).
    rewrite Hbef //=. rewrite Hyf.  have: (r <= y) by []. by move ->. by [].  
    move => [Ha Hprev]. move : Ha => /(_ f). rewrite nth_ord_enum => /andP[Hleq Ha].
    rewrite Hleq Ha. repeat(split; try by []). move => x /andP[Hxr Hxf]. move : Hprev => /(_ r x).
    rewrite Hxf nth_ord_enum. move => Hor. have : ~~ ((r <= x) && (A x col != 0)) by rewrite {1}/negb Hor.
    move : Hor => H{H}. rewrite Bool.negb_andb => /orP[Hrx | Hac]. move : Hxr Hrx. by move ->.
    move : Hac. rewrite /negb. by case: (A x col == 0).
  - apply r.
  - by rewrite size_ord_enum. 
  - move ->. rewrite /fst_nonzero. have Hbound := (fst_nonzero_nat_bound A col r).
    move : Hbound => /orP[Heq | Hlt].
    + rewrite insubF. split. by []. eq_subst Heq. rewrite Heq. move => Hmf. 
      have: (f < m) by []. move => Hfmlt. rewrite -Hmf in Hfmlt.
      rewrite ltnn in Hfmlt. by []. eq_subst Heq. rewrite Heq. apply ltnn. 
    + rewrite insubT. split. move => Hs. case : Hs. move => Hf. rewrite -Hf. by [].
      move => Hfst. f_equal. have : (nat_of_ord (Sub (fst_nonzero_nat A col r) Hlt) == nat_of_ord f).
      by rewrite -Hfst. move => Hnatord. have : (Sub (fst_nonzero_nat A col r) Hlt  == f).
      by []. move => Hsub. by eq_subst Hsub.
Qed. 

Lemma fst_nonzero_none: forall {m n} (A: 'M[F]_(m, n)) (col: 'I_n) (r: 'I_m),
  fst_nonzero A col r = None ->
  forall (x : 'I_m), r <= x -> A x col = 0.
Proof.
  move => m n A col r. rewrite /fst_nonzero.
  case : (orP (fst_nonzero_nat_bound A col r)) => [ Heq | Hlt].
  move => H{H}. move : Heq. rewrite /fst_nonzero_nat. have Hsz := size_ord_enum m. move => Hfind.
  have : (find (fun x : 'I_m => (r <= x) && (A x col != 0)) (ord_enum m) == size (ord_enum m)).
  by rewrite Hsz. move {Hfind} => /eqP Hfind. move => x Hrx. apply find_none with (x0:=x) in Hfind.
  move : Hfind. rewrite negb_and => /orP[Hnrx | Hxcol]. by move: Hrx Hnrx ->. apply (elimT eqP).
  move : Hxcol. by case : (A x col == 0). apply mem_ord_enum.
  by rewrite insubT.
Qed. 

(*Now, we define the leading coefficient of a row (ie, the first nonzero element) - will be n if row is all zeroes*)
(*We also want an ordinal, so we do something similar to above*)
Definition lead_coef_nat {m n} (A: 'M[F]_(m, n)) (row: 'I_m) : nat :=
  find (fun x => A row x != 0) (ord_enum n).

Definition lead_coef {m n} (A: 'M[F]_(m, n)) (row: 'I_m) : option 'I_n := insub (lead_coef_nat A row).

Lemma lead_coef_nat_bound : forall {m n} (A: 'M[F]_(m, n)) (row: 'I_m),
  (lead_coef_nat A row == n) || (lead_coef_nat A row < n).
Proof.
  move => m n A row. rewrite /lead_coef_nat.
  have Hsz := find_size (fun (x : 'I_n) => A row x != 0) (ord_enum n). move : Hsz.
  by rewrite size_ord_enum leq_eqVlt.
Qed.

(*Specification for the some case*)
Lemma lead_coef_some_iff: forall {m n} (A: 'M[F]_(m, n)) (row: 'I_m) c,
  lead_coef A row = Some c <-> (A row c != 0) /\ (forall (x : 'I_n), x < c -> A row x = 0).
Proof.
  move => m n A row c. have: A row c != 0 /\ (forall x : 'I_n, x < c -> A row x = 0) <-> lead_coef_nat A row = c.
  rewrite /lead_coef_nat. rewrite find_iff. split.
  - move => [Harc Hprev]. split; move => x. by rewrite nth_ord_enum. move => y Hyc.
    rewrite Hprev. by rewrite eq_refl. have Hyn : y < n. have : c < n by [].
    move : Hyc. apply ltn_trans. have : nth x (ord_enum n) y == nth x (ord_enum n) (Ordinal Hyn) by [].
    move => /eqP Hnth. by rewrite Hnth nth_ord_enum.
  - move => [Harc Hprev]. move : Harc => /(_ c). rewrite nth_ord_enum. move : Hprev => /(_ c) Hprev Harc.
    split. by []. move => x Hxc. move : Hprev => /(_ x). rewrite Hxc nth_ord_enum.
    case Heq : ( A row x == 0). eq_subst Heq. rewrite Heq. by [].
    rewrite //=. move => Hcon. have: true = false by rewrite Hcon. by [].
  - apply c.
  - by rewrite size_ord_enum.
  - move ->. rewrite /lead_coef. have Hbound := (lead_coef_nat_bound A row).
    move : Hbound => /orP[Heq | Hlt].
    + rewrite insubF. split. by []. eq_subst Heq. rewrite Heq. move => Hnc. 
      have: (c < n) by []. move => Hcnlt. rewrite -Hnc in Hcnlt.
      by rewrite ltnn in Hcnlt. eq_subst Heq. rewrite Heq. apply ltnn. 
    + rewrite insubT. split. move => Hs. case : Hs. move => Hf. rewrite -Hf. by [].
      move => Hfst. f_equal. have : (nat_of_ord (Sub (lead_coef_nat A row) Hlt) == nat_of_ord c)
      by rewrite -Hfst. move => Hnatord. 
      have : (Sub (lead_coef_nat A row) Hlt == c) by []. by move => /eqP Heq.
Qed. (*TODO: maybe try to reduce duplication between this and previous*)

(*Fold a function over the rows of a matrix that are contained in a list.
  If this function only affects a single row and depends only on the entries in that row and possibly
  rows that are not in the list, then we can describe the (i, j)th component just with the function itself.
  This allows us to prove things about the multiple intermediate steps in gaussian elimination at once*)

(*Two helper lemmas*)
Lemma mx_row_transform_notin: forall {m n} (A: 'M[F]_(m,n)) (f: 'I_m -> 'M[F]_(m,n) -> 'M[F]_(m,n)) (l: seq 'I_m),
  (forall (A: 'M[F]_(m,n)) i j r, i != r ->  A i j = (f r A) i j) ->
  forall r j, r \notin l ->
  (foldr f A l) r j = A r j.
Proof.
  move => m n A f l Hfcond. elim: l => [//| h t IH].
  move => r j. rewrite in_cons negb_or => /andP[Hhr Hnotint] //=. rewrite -Hfcond. by apply: IH. by []. 
Qed. 

Lemma row_function_equiv: forall {m n} (A: 'M[F]_(m,n)) (l : seq 'I_m) (r : 'I_m) (f: 'I_m -> 'M[F]_(m,n) -> 'M[F]_(m,n)),
  (forall (A : 'M_(m, n)) (i : ordinal_eqType m) (j : 'I_n) r,
         i != r -> A i j = f r A i j) -> (*f only changes entries in r*)
  (forall (A B : 'M[F]_(m,n)), (forall j, A r j = B r j) -> (forall r' j, r' \notin l -> A r' j = B r' j) ->
    forall j, (f r A) r j = (f r B) r j) -> (*f depends only on values in row r and rows not in the list*) 
  r \notin l ->
  forall j, (f r (foldr f A l)) r j = (f r A) r j.
Proof.
  move => m n A l r f Hres Hinp Hinr' j. rewrite (Hinp _ A). by []. move => j'. apply: mx_row_transform_notin.
  by []. by []. apply: mx_row_transform_notin. by [].
Qed. 

(*How we can describe the entries of the resulting list (all other entries are handled by [mx_row_transform_notin]*)
Lemma mx_row_transform: forall {m n} (A: 'M[F]_(m,n)) (f: 'I_m -> 'M[F]_(m,n) -> 'M[F]_(m,n)) (l: seq 'I_m) r,
  (forall (A: 'M[F]_(m,n)) i j r, i != r ->  A i j = (f r A) i j) ->
  (forall (A B : 'M[F]_(m,n)), (forall j, A r j = B r j) -> (forall r' j, r' \notin l -> A r' j = B r' j) ->
    forall j, (f r A) r j = (f r B) r j) ->
  uniq l ->
  forall j, r \in l ->
  (foldr f A l) r j = (f r A) r j.
Proof.
  move => m n A f l r Hfout. elim: l => [//| h t IH]. rewrite //= => Hfin /andP[Hnotin Huniq] j.
  rewrite //= in_cons. move /orP => [/eqP Hhr | Hinr]. subst. apply (row_function_equiv).
  apply: Hfout. move => A' B H1 H2. apply: Hfin. apply: H1. move => r'' j'' Hnotin'. apply: H2.
  move : Hnotin'. by rewrite in_cons negb_or => /andP[Heq Hnin]. by [].
  rewrite -Hfout. apply: IH; rewrite //. move => A' B' H1 H2. apply: Hfin; rewrite //.
  move => r'' j''. rewrite in_cons negb_or => /andP[Heq Hnin]. by apply: H2.
  case Heq : (r == h). move : Heq => /eqP Heq. subst. move : Hinr Hnotin. move ->. by []. by [].
Qed.

(*This resulting matrix is row equivalent if f is*)
Lemma mx_row_transform_equiv: forall {m n} (A: 'M[F]_(m,n)) (f: 'I_m -> 'M[F]_(m,n) -> 'M[F]_(m,n)) (l: seq 'I_m),
  (forall (A: 'M[F]_(m, n)) (r : 'I_m), row_equivalent A (f r A)) ->
  row_equivalent A (foldr f A l).
Proof.
  move => m n A f l Hre. elim: l => [//=| h t IH].
  apply: row_equiv_refl. rewrite //=. apply (row_equivalent_trans IH). apply Hre.
Qed. 

(*Now we can define the gaussian elimination functions*)

(*make all entries in column c 1 or zero*)
Definition all_cols_one {m n} (A: 'M[F]_(m, n)) (c: 'I_n) :=
  foldr (fun x acc => let f := A x c in if f == 0 then acc else (sc_mul acc (f^-1) x)) A (ord_enum m).

Lemma all_cols_one_val: forall {m n} (A: 'M[F]_(m,n)) c i j,
  (all_cols_one A c) i j = let f := A i c in if f == 0 then A i j else A i j / f.
Proof.
  move => m n A c i j. rewrite mx_row_transform. 
  - rewrite //=. case Heq: (A i c == 0) => [//|].
    by rewrite /sc_mul mxE eq_refl GRing.mulrC.
  - move => A' i' j' r'. rewrite /=. case (A r' c == 0) => [//|//=].
    rewrite /sc_mul mxE /negb. by case: (i' == r').
  - move => A' B' Hin Hout j'. rewrite /=. case: (A i c == 0).
    apply Hin. by rewrite /sc_mul mxE mxE eq_refl Hin.
  - apply ord_enum_uniq.
  - apply mem_ord_enum.
Qed.

Lemma all_cols_one_row_equiv: forall {m n} (A: 'M[F]_(m,n)) c,
  row_equivalent A (all_cols_one A c).
Proof.
  move => m n A c. apply mx_row_transform_equiv.
  move => A' r. rewrite //=. case Hz: (A r c == 0).
  - constructor.
  - apply ero_row_equiv. constructor. apply GRing.Theory.invr_neq0. by rewrite Hz.
Qed.

(*A version of [rem] that instead removes all matching elements. In our case, it is the same, but we
  can prove a more general lemma about foldr*)

Definition remAll  {A: eqType} (x : A) (l : seq A) := filter (predC1 x) l.

Lemma foldr_remAll: forall {A : eqType} {B} (l: seq A) (f: A -> B -> B) (base: B) (z: A),
  foldr (fun x acc => if (x == z) then acc else f x acc) base l =
  foldr f base (remAll z l).
Proof.
  move => A B l. elim: l => [//| h t IH f base z /=]. rewrite /negb. case : (h == z).
  by rewrite IH. by rewrite /= IH.
Qed.

Lemma remAll_notin: forall {A: eqType} (x: A) (l: seq A),
  x \notin (remAll x l).
Proof.
  move => A x l. elim: l => [// | h t IH //=].
  rewrite {2}/negb. case Heq:  (h == x). exact IH. rewrite in_cons Bool.negb_orb.
  by rewrite {1}/negb eq_sym Heq IH.
Qed. 

Lemma remAll_in: forall {A: eqType} (x y : A) (l: seq A),
  x != y ->
  x \in l ->
  x \in (remAll y l).
Proof.
  move => A x y l. elim : l => [//| h t IH Hneq /=].
  rewrite in_cons; move /orP => [Hxh | Ht]. eq_subst Hxh. rewrite Hneq.
  by rewrite in_cons eq_refl.
  have: x \in remAll y t. by apply IH. case : (h != y) => [|//].
  rewrite in_cons. move ->. by rewrite orbT.
Qed. 

Lemma rem_remAll: forall {A: eqType} (x : A) (l: seq A),
  uniq l ->
  rem x l = remAll x l.
Proof.
  move => A x l Hu. by rewrite rem_filter.
Qed. 


(*Subtract row r from all rows except row r (if A r' c = 0)*) 
Definition sub_all_rows {m n} (A: 'M[F]_(m, n)) (r : 'I_m) (c : 'I_n) : 'M[F]_(m, n) :=
  foldr (fun x acc => if x == r then acc else let f := A x c in
                        if f == 0 then acc else add_mul acc (- 1) r x) A (ord_enum m). 

Lemma sub_all_rows_val: forall {m n} (A: 'M[F]_(m,n)) r c i j,
  (sub_all_rows A r c) i j = if i == r then A i j else
                            if A i c == 0 then A i j else A i j - A r j.
Proof.
  move => m n A r c i j. rewrite /sub_all_rows. rewrite foldr_remAll. case Hir : (i == r).
  eq_subst Hir. rewrite mx_row_transform_notin. by []. move => A' i' j' r'.
  case : (A r' c == 0). by []. rewrite /add_mul mxE //= /negb. by case : (i' == r').
  apply remAll_notin. 
  rewrite mx_row_transform.
  - case (A i c == 0) => [// | ]. by rewrite /add_mul mxE eq_refl GRing.mulN1r.
  - move => A' i' j' r'. case : (A r' c == 0) => [//|].
    rewrite /add_mul mxE /negb. by case H : (i' == r').
  - move => A' B' Hin Hout j'. case : (A i c == 0). apply Hin.
    rewrite !/add_mul !mxE !eq_refl !Hin.
    rewrite Hout => [//|]. apply remAll_notin.
  - rewrite -rem_remAll. apply rem_uniq. all: apply ord_enum_uniq.
  - apply remAll_in. by rewrite Hir. by rewrite mem_ord_enum.
Qed.

Lemma sub_all_rows_row_equiv: forall {m n} (A: 'M[F]_(m,n)) r c,
  row_equivalent A (sub_all_rows A r c).
Proof.
  move => m n A r c. apply mx_row_transform_equiv.
  move => A' r'. rewrite //=. case Heq : (r' == r).
  constructor. case: (A r' c == 0). constructor.
  apply ero_row_equiv. constructor. by rewrite eq_sym Heq.
Qed.

(** The Algorithm *)

(*The state of the matrix when we have computed gaussian elimination up to row r and column c*)
Definition gauss_invar {m n} (A: 'M[F]_(m, n)) (r : nat) (c: nat) :=
  (forall (r' : 'I_m), r' < r -> exists c', lead_coef A r' = Some c' /\ c' < c) /\ (*all rows up to r have leading coefficient before column c*) 
  (forall (r1 r2 : 'I_m) c1 c2, r1 < r2 -> r2 < r -> lead_coef A r1 = Some c1 -> lead_coef A r2 = Some c2 ->
    c1 < c2) /\ (*leading coefficients occur in strictly increasing columns*)
  (forall (r' : 'I_m) (c' : 'I_n), c' < c -> lead_coef A r' = Some c' -> 
     (forall (x: 'I_m), x != r' -> A x c' = 0)) /\ (*columns with leading coefficients have zeroes in all other entries*) 
  (forall (r' : 'I_m) (c' : 'I_n), r <= r' ->  c' < c -> A r' c' = 0). (*first c entries of rows >= r are all zero*)

(*One step of gaussian elimination*)
Definition gauss_one_step {m n} (A: 'M[F]_(m, n)) (r: 'I_m) (c: 'I_n) : 'M[F]_(m, n) * (option 'I_m) * (option 'I_n) :=
  match (fst_nonzero A c r) with
  | None => (A, Some r, insub (c.+1))
  | Some k =>
    let A1 := xrow k r A in
    let A2 := all_cols_one A1 c in
    let A3 := sub_all_rows A2 r c in
    (A3, insub (r.+1), insub (c.+1))
  end.

(*Results about the structure of the matrix after 1 step of gaussian elim. We use these lemmas to prove invariant
  preservation*)

(*First, in the first r rows and c columns, we did not change whether any entries are zero or not*)
Lemma gauss_one_step_beginning_submx: forall {m n} (A: 'M[F]_(m, n)) (r: 'I_m) (c: 'I_n) (k : 'I_m),
  (forall (r' : 'I_m) (c' : 'I_n), r <= r' ->  c' < c -> A r' c' = 0) ->
  r <= k ->
  forall (x : 'I_m) (y: 'I_n), x < r -> y < c -> 
    A x y == 0 = ((sub_all_rows (all_cols_one (xrow k r A) c) r c) x y == 0).
Proof.
  move => m n A r c k Hinv Hrk x y Hxr Hyc. rewrite sub_all_rows_val.
  case Heq : (x == r). move : Heq. have H := ltn_eqF Hxr. have : x == r = false by []. move ->. by [].
  have: (forall y, all_cols_one (xrow k r A) c x y = all_cols_one A c x y).
    move => z. rewrite !all_cols_one_val //=.
    have: (x == k) = false. apply ltn_eqF. move: Hxr Hrk. apply ltn_leq_trans.
    move => Hxkneq. have: forall j, (xrow k r A x j) = A x j.
    move => j. by rewrite xrow_val Hxkneq Heq. move => Hxrowj.
    rewrite !Hxrowj. by []. move => Hallcols.
 rewrite !Hallcols.
 have : (A x y == 0) = (all_cols_one A c x y == 0). rewrite all_cols_one_val /=. case Hac : (A x c == 0). by [].
   by rewrite GRing.mulf_eq0 GRing.invr_eq0 Hac orbF.
 case Hall : (all_cols_one A c x c == 0). 
  - by [].
  - have: all_cols_one (xrow k r A) c r y == 0. rewrite all_cols_one_val //=.
    have: forall z, xrow k r A r z = A k z. move => z. rewrite xrow_val.
    case H: (r==k). by eq_subst H. by rewrite eq_refl. move => Hxrow. rewrite !Hxrow.
    have: A k y == 0. by rewrite Hinv. move => H; eq_subst H. rewrite H.
    case: (A k c == 0). by []. by rewrite GRing.mul0r.
    move => /eqP Hallry. by rewrite Hallry GRing.subr0.
Qed.

(* Second (this holds in general for any matrix) - all entries in the resulting matrix column c are zero, except r is one*)
Lemma gauss_one_step_col_c: forall {m n} (A: 'M[F]_(m, n)) (r: 'I_m) (c: 'I_n) (k : 'I_m),
  A k c != 0 ->
  forall (x : 'I_m), (sub_all_rows (all_cols_one (xrow k r A) c) r c) x c = if x == r then 1 else 0.
Proof.
  move => m n A r c k Hkc x. rewrite sub_all_rows_val.
   have: xrow k r A r c = A k c. rewrite xrow_val.
    case H : (r==k). by eq_subst H. by rewrite eq_refl.
  case Hxr : (x == r).
  - rewrite all_cols_one_val /=. eq_subst Hxr.
    move ->. move : Hkc. rewrite /negb. case Hkc : (A k c == 0) => [//|//=].
    rewrite GRing.mulfV => [//|]. move : Hkc. rewrite /negb. by move ->.
  - move => Hxrow. 
    have: all_cols_one (xrow k r A) c r c == 1. rewrite all_cols_one_val //= !Hxrow.
    move : Hkc. rewrite /negb. case Heq : (A k c == 0) => [//|].
    rewrite GRing.mulfV => [//|]. move : Heq. rewrite /negb. by move ->. move => /eqP Hrc1.
    rewrite Hrc1. case Hallcol : (all_cols_one (xrow k r A) c x c == 0). apply (elimT eqP). 
    by rewrite Hallcol. move : Hallcol. rewrite all_cols_one_val /=.
    case Hxc : (xrow k r A x c == 0 ). by rewrite Hxc. move => H{H}.
    rewrite GRing.mulfV. apply (elimT eqP). by rewrite GRing.subr_eq0 eq_refl. move : Hxc. rewrite /negb. by move ->.
Qed. 

(*Third - all entries with row >=r and col < c are still zero*)
Lemma gauss_one_step_bottom_rows: forall {m n} (A: 'M[F]_(m, n)) (r: 'I_m) (c: 'I_n) (k : 'I_m),
  (forall (r' : 'I_m) (c' : 'I_n), r <= r' ->  c' < c -> A r' c' = 0) ->
  fst_nonzero A c r = Some k ->
  forall (x : 'I_m) (y: 'I_n), r <= x -> y < c -> 
    (sub_all_rows (all_cols_one (xrow k r A) c) r c) x y = 0.
Proof.
  move => m n A r c k Hinv Hfst x y Hrx Hyc. move : Hfst. rewrite fst_nonzero_some_iff. move => [Hrk [Hakc Hprev]].
  rewrite sub_all_rows_val. move : Hrx.
  have: forall z, xrow k r A r z = A k z. move => z. rewrite xrow_val.
    case H : (r == k). by eq_subst H. by rewrite eq_refl. move => Hxrow.
 rewrite leq_eqVlt eq_sym =>
  /orP[Hrx | Hrx]. 
  - have Hxr' : (x == r) by []. rewrite Hxr'. eq_subst Hxr'.
    rewrite all_cols_one_val /=. rewrite !Hxrow.
    case (A k c == 0). by apply Hinv.  rewrite Hinv. by rewrite GRing.mul0r. all: by [].
  - have : x == r = false by apply gtn_eqF. move => Hxrneq. rewrite Hxrneq.
    have: all_cols_one (xrow k r A) c r y = 0. rewrite all_cols_one_val /=.
    rewrite ! Hxrow. have: A k y = 0 by apply Hinv. move ->.
    case (A k c == 0). by []. by rewrite GRing.mul0r. move ->. rewrite GRing.subr0.
    have: all_cols_one (xrow k r A) c x y = 0. rewrite all_cols_one_val /=.
    case Hxk : (x == k). eq_subst Hxk. 
    have: forall z, xrow k r A k z = A r z. move => z. by rewrite xrow_val eq_refl.
    move ->. rewrite Hprev. rewrite xrow_val eq_refl. apply Hinv. apply leqnn.
    by []. by rewrite Hrx leqnn.
    have: forall z, xrow k r A x z = A x z. move => z. rewrite xrow_val.
    rewrite Hxk Hxrneq. by []. move => Hx. rewrite !Hx.
    have : A x y = 0. apply Hinv. by rewrite leq_eqVlt Hrx orbT. by [].
    move ->. case : (A x c == 0) => [//|]. by rewrite GRing.mul0r.
    move ->. by case (all_cols_one (xrow k r A) c x c == 0).
Qed.

(*Fourth - for all rows < r, the leading coefficient has not changed (this follows from the others)*)
Lemma gauss_one_step_prop_lead_coef: forall {m n} (A: 'M[F]_(m, n)) (r: 'I_m) (c: 'I_n) (k : 'I_m),
  (forall (r' : 'I_m) (c' : 'I_n), r <= r' ->  c' < c -> A r' c' = 0) ->
  (forall (r' : 'I_m), r' < r -> exists c', lead_coef A r' = Some c' /\ c' < c) ->
  fst_nonzero A c r = Some k ->
  forall (r' : 'I_m), r' < r -> 
    lead_coef A r' = lead_coef (sub_all_rows (all_cols_one (xrow k r A) c) r c) r'.
Proof.
  move => m n A r c k Hzero Hlead Hfz r' Hrr'. move : Hlead => /(_ r'). rewrite Hrr' => Hlc.
  have Hlcr' : (exists c' : 'I_n, lead_coef A r' = Some c' /\ c' < c) by apply Hlc.
  move : {Hlc} Hlcr' => [c' [Hlc Hcc']]. rewrite Hlc. have Hrk : r <= k. move : Hfz.
  rewrite fst_nonzero_some_iff. by move => [Hrk [Hakc Hprev]]. 
  have Hbeg := (gauss_one_step_beginning_submx Hzero Hrk).
  symmetry. move : Hlc. rewrite !lead_coef_some_iff. move => [Harc' Hprev].
  split. by rewrite -Hbeg. move => x Hxc'. 
  have: sub_all_rows (all_cols_one (xrow k r A) c) r c r' x == 0. rewrite -Hbeg. rewrite Hprev. all: try by [].
  move : Hxc' Hcc'. by apply ltn_trans. by move => /eqP Hs.
Qed.

(*Finally, leading coefficient of row r is c*)
Lemma gauss_one_step_r_lead: forall {m n} (A: 'M[F]_(m, n)) (r: 'I_m) (c: 'I_n) (k : 'I_m),
  (forall (r' : 'I_m) (c' : 'I_n), r <= r' ->  c' < c -> A r' c' = 0) ->
  fst_nonzero A c r = Some k ->
  lead_coef (sub_all_rows (all_cols_one (xrow k r A) c) r c) r = Some c.
Proof.
  move => m n A r c l Hz. rewrite lead_coef_some_iff. move => Hfst. split; move : Hfst.
  rewrite fst_nonzero_some_iff; move => [Hrl [Hlc H{H}]]. 
  have Hc := gauss_one_step_col_c r  Hlc r. by rewrite Hc eq_refl GRing.oner_neq0.
  move => Hfz x Hxc. by apply gauss_one_step_bottom_rows.
Qed.

Definition ord_bound_convert {n} (o: option 'I_n) : nat :=
  match o with
  | None => n
  | Some x => x
  end.

Lemma ord_bound_convert_plus: forall {n} (x : 'I_n),
  @ord_bound_convert n (insub (x.+1)) = (x.+1).
Proof.
  move => n x. have: x < n by []. rewrite leq_eqVlt => /orP[/eqP Heq | Hlt].
  rewrite insubF. by rewrite Heq. by rewrite Heq ltnn.
  by rewrite insubT.
Qed.

(*Note: this is a little awkward because r and c are bounded (and need to be for the functions called in
  [gauss_one_step]. However, in gaussian elimination, when we finish,
  r or c will achieve the bound. Instead of having to carry options around everywhere, we phrase the invariant
  in terms of nats, which forces us to unwrap the option with [ord_bound_convert]*)
Lemma gauss_one_step_invar: forall {m n} (A: 'M[F]_(m, n)) (r: 'I_m) (c: 'I_n),
  gauss_invar A r c ->
  match (gauss_one_step A r c) with
  | (A', or, oc) => gauss_invar A' (ord_bound_convert or) (ord_bound_convert oc)
  end.
Proof.
  move => m n A r c Hinv. case G : (gauss_one_step A r c) => [[A' or] oc]. move : G.
  rewrite /gauss_one_step. case Fz : (fst_nonzero A c r) => [k |]; rewrite //=.
  - move => G. case : G => Ha' Hor Hoc. subst.
    move : Hinv. rewrite {1}/gauss_invar; move => [Hleadbefore [Hincr [Hzcol Hzero]]].
    rewrite /gauss_invar. rewrite !ord_bound_convert_plus. split; try split; try split.
    + move => r'. rewrite ltnS leq_eqVlt; move => /orP[Hrr' | Hrr'].
      * have : r' == r by []. rewrite {Hrr'} => /eqP Hrr'. subst. exists c.
        split. by apply gauss_one_step_r_lead. by [].
      * have Hlead2 := Hleadbefore. move : Hleadbefore => /(_ r' Hrr') [c' [Hlc Hcc']]. exists c'. split.
        by rewrite -gauss_one_step_prop_lead_coef. have : c < c.+1 by []. move : Hcc'; apply ltn_trans.
    + move => r1 r2 c1 c2 Hr12. rewrite ltnS leq_eqVlt; move => /orP[Hr2r | Hr2r].
      * have: (r2 == r) by []. move {Hr2r} => /eqP Hr2r. subst. rewrite gauss_one_step_r_lead =>[|//|//].
        rewrite -gauss_one_step_prop_lead_coef => [| //|//|//|//].
        move => Hl1 Hl2. case : Hl2 => Hl2. subst. move : Hleadbefore => /(_ r1 Hr12) [c'] . move => [Hlc Hcc'].
        rewrite Hlc in Hl1. case: Hl1. by move => H; subst.
      * have Hr1r : r1 < r. move : Hr12 Hr2r. by apply ltn_trans.
        rewrite -!gauss_one_step_prop_lead_coef; try by []. by apply Hincr. 
    + move => r' c'. rewrite ltnS leq_eqVlt; move => /orP[Hcc' | Hcc'].
      * have : (c' == c) by []. rewrite {Hcc'} => /eqP H; subst.
        (*need to show that if leading coefficient of r' is c, then r' = r*)
        case Hrr' : (r' == r).
        -- move => H{H} x Hxr. rewrite gauss_one_step_col_c.
           have : x == r = false. have Hreq : (r' == r) by []. eq_subst Hreq.
           move: Hxr. by case : (x == r). move ->. by []. move : Fz.
           rewrite fst_nonzero_some_iff. by move => [Hrk [Hakc H]].
        -- rewrite lead_coef_some_iff. move => [Hnonz Hbef]. move : Hnonz.
           rewrite gauss_one_step_col_c. by rewrite Hrr' eq_refl. move: Fz.
           rewrite fst_nonzero_some_iff. by move => [H1 [H2 H3]].
      * (*this time, need to show that r' < r. Cannot be greater because entry is 0*)
        case (orP (ltn_total r r')) => [/orP[Hltxr | Heqxr] | Hgtxr].
        -- rewrite lead_coef_some_iff. move => [Hnonzero  H{H}].
           move : Hnonzero. rewrite gauss_one_step_bottom_rows; try by [].
           by rewrite eq_refl. by rewrite leq_eqVlt Hltxr orbT.
        -- have H: (r == r') by []; eq_subst H.
           rewrite gauss_one_step_r_lead => [|//|//]. move => H; case : H. move => H; move : H Hcc' ->.
           by rewrite ltnn.
        -- rewrite -gauss_one_step_prop_lead_coef; try by []. move => Hl x Hxr.
           case (orP (ltn_total r x)) => [Hgeq | Hlt].
           ++ have Hrx : (r <= x). by rewrite leq_eqVlt orbC. move {Hgeq}. 
              by apply gauss_one_step_bottom_rows.
           ++ apply (elimT eqP). rewrite -gauss_one_step_beginning_submx; try by [].
              rewrite (Hzcol r'); try by []. move : Fz. rewrite fst_nonzero_some_iff. by move => [H H'].
    + move => r' c' Hrr'. rewrite ltnS leq_eqVlt; move => /orP[Hcc' | Hcc'].
      * have H: (c' == c) by []; eq_subst H. rewrite gauss_one_step_col_c.
        have: r' == r = false by apply gtn_eqF. by move ->. move: Fz. rewrite fst_nonzero_some_iff.
        by move => [H [H' H'']].
      * apply gauss_one_step_bottom_rows; try by []. by rewrite leq_eqVlt Hrr' orbT.
  - have: forall (x: 'I_m), r <= x -> A x c = 0 by apply fst_nonzero_none. move {Fz} => Fz.
    move => G. case : G => Ha' Hor Hoc. subst.
    move : Hinv. rewrite {1}/gauss_invar; move => [Hleadbefore [Hincr [Hzcol Hzero]]].
    rewrite /gauss_invar. rewrite !ord_bound_convert_plus. rewrite /ord_bound_convert. split; try split; try split.
    + move => r' Hrr'.  move : Hleadbefore => /(_ r' Hrr') [c' [Hlc Hcc']]. exists c'. split. by [].
      have: (c < c.+1) by []. move : Hcc'. by apply ltn_trans.
    + by [].
    + move => r' c'. rewrite ltnS leq_eqVlt; move => /orP[Hcc' | Hcc'].
      have :(c' == c) by []. move => /eqP H; subst.
      case (orP (ltn_total r r')) => [Hgeq | Hlt]. 
      * have Hrx : (r <= r'). by rewrite leq_eqVlt orbC. move {Hgeq}. 
        rewrite lead_coef_some_iff Fz. rewrite eq_refl. by move => [H H']. by [].
      * move => Hlc. move : Hleadbefore => /(_ r' Hlt) [c' [Hlc' Hltcc']].
        rewrite Hlc in Hlc'. case: Hlc'. move => H; subst. move : Hltcc'. by rewrite ltnn.
      * by apply Hzcol.
    + move => r' c' Hrr'. rewrite ltnS leq_eqVlt; move => /orP[Hcc' | Hcc'].
      * have : (c' == c) by []. move => /eqP H; subst. by apply Fz.
      * by apply Hzero.
Qed.


End Gauss.