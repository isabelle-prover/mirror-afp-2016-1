(*
    Authors:      Jose Divasón
                  Sebastiaan Joosten
                  René Thiemann
                  Akihisa Yamada
*)
subsection \<open>Finite Fields\<close>

text \<open>We provide two implementations for $GF(p)$ -- the field with $p$ elements for some
  prime $p$ -- one by integers and one by bit-vectors. 
  Correctness of the implementations is proven by
  transfer rules to the type-based version of $GF(p)$.\<close>

theory Finite_Field_Record_Based
imports
  Finite_Field
  Arithmetic_Record_Based
  "../Native_Word/Uint32" 
  "../Native_Word/Code_Target_Bits_Int"
  "~~/src/HOL/Library/Code_Target_Numeral"  
begin

(* mod on standard case which can immediately be mapped to 
   target languages without considering special cases *)
definition mod_nonneg_pos :: "integer \<Rightarrow> integer \<Rightarrow> integer" where
  "x \<ge> 0 \<Longrightarrow> y > 0 \<Longrightarrow> mod_nonneg_pos x y = (x mod y)" 
  
code_printing
  constant mod_nonneg_pos \<rightharpoonup>
        (SML) "IntInf.mod/ ( _,/ _ )"
    and (Haskell) "Prelude.mod/ ( _ )/ ( _ )"
    and (Eval) "IntInf.mod/ ( _,/ _ )" 
    and (OCaml) "Big'_int.mod'_big'_int/ ( _ )/ ( _ )"
    and (Scala) "!((k: BigInt) => (l: BigInt) =>/ (k '% l))"

definition mod_nonneg_pos_int :: "int \<Rightarrow> int \<Rightarrow> int" where
  "mod_nonneg_pos_int x y = int_of_integer (mod_nonneg_pos (integer_of_int x) (integer_of_int y))" 

lemma mod_nonneg_pos_int[simp]: "x \<ge> 0 \<Longrightarrow> y > 0 \<Longrightarrow> mod_nonneg_pos_int x y = (x mod y)" 
  unfolding mod_nonneg_pos_int_def using mod_nonneg_pos_def by simp

context
  fixes p :: int
begin
definition plus_p :: "int \<Rightarrow> int \<Rightarrow> int" where
  "plus_p x y \<equiv> let z = x + y in if z \<ge> p then z - p else z"

definition minus_p :: "int \<Rightarrow> int \<Rightarrow> int" where
  "minus_p x y \<equiv> if y \<le> x then x - y else x + p - y"

definition uminus_p :: "int \<Rightarrow> int" where
  "uminus_p x = (if x = 0 then 0 else p - x)"

definition mult_p :: "int \<Rightarrow> int \<Rightarrow> int" where
  "mult_p x y = (mod_nonneg_pos_int (x * y) p)"

fun power_p :: "int \<Rightarrow> nat \<Rightarrow> int" where
  "power_p x n = (if n = 0 then 1 else
    let (d,r) = Divides.divmod_nat n 2;
       rec = power_p (mult_p x x) d in
    if r = 0 then rec else mult_p rec x)"

text \<open>In experiments with Berlekamp-factorization (where the prime $p$ is usually small),
  it turned out that taking the below implementation of inverse via exponentiation
  is faster than the one based on the extended Euclidean algorithm.\<close>

definition inverse_p :: "int \<Rightarrow> int" where
  "inverse_p x = (if x = 0 then 0 else power_p x (nat (p - 2)))"

definition divide_p :: "int \<Rightarrow> int \<Rightarrow> int"  where
  "divide_p x y = mult_p x (inverse_p y)"

definition finite_field_ops :: "int arith_ops_record" where
  "finite_field_ops \<equiv> Arith_Ops_Record
      0
      1
      plus_p
      mult_p
      minus_p
      uminus_p
      divide_p
      inverse_p
      (\<lambda> x y . if y = 0 then x else 0)
      (\<lambda> x . if x = 0 then 0 else 1)
      (\<lambda> x . x)
      (\<lambda> x . x)
      (\<lambda> x . x)
      (\<lambda> x. 0 \<le> x \<and> x < p)"

end

context
  fixes p :: uint32
begin
definition plus_p32 :: "uint32 \<Rightarrow> uint32 \<Rightarrow> uint32" where
  "plus_p32 x y \<equiv> let z = x + y in if z \<ge> p then z - p else z"

definition minus_p32 :: "uint32 \<Rightarrow> uint32 \<Rightarrow> uint32" where
  "minus_p32 x y \<equiv> if y \<le> x then x - y else (x + p) - y"

definition uminus_p32 :: "uint32 \<Rightarrow> uint32" where
  "uminus_p32 x = (if x = 0 then 0 else p - x)"

definition mult_p32 :: "uint32 \<Rightarrow> uint32 \<Rightarrow> uint32" where
  "mult_p32 x y = (x * y mod p)"

lemma int_of_uint32_shift: "int_of_uint32 (shiftr n k) = (int_of_uint32 n) div (2 ^ k)" 
  by (transfer, rule shiftr_div_2n) 

lemma int_of_uint32_0_iff: "int_of_uint32 n = 0 \<longleftrightarrow> n = 0" 
  by (transfer, rule uint_0_iff)
  
lemma int_of_uint32_0: "int_of_uint32 0 = 0" unfolding int_of_uint32_0_iff by simp

lemma int_of_uint32_ge_0: "int_of_uint32 n \<ge> 0" 
  by (transfer, auto)

lemma two_32: "2 ^ LENGTH(32) = (4294967296 :: int)" by simp

lemma int_of_uint32_plus: "int_of_uint32 (x + y) = (int_of_uint32 x + int_of_uint32 y) mod 4294967296" 
  by (transfer, unfold uint_word_ariths two_32, rule refl)  

lemma int_of_uint32_minus: "int_of_uint32 (x - y) = (int_of_uint32 x - int_of_uint32 y) mod 4294967296" 
  by (transfer, unfold uint_word_ariths two_32, rule refl)  

lemma int_of_uint32_mult: "int_of_uint32 (x * y) = (int_of_uint32 x * int_of_uint32 y) mod 4294967296" 
  by (transfer, unfold uint_word_ariths two_32, rule refl)  

lemma int_of_uint32_mod: "int_of_uint32 (x mod y) = (int_of_uint32 x mod int_of_uint32 y)" 
  by (transfer, unfold uint_mod two_32, rule refl)  

lemma int_of_uint32_inv: "0 \<le> x \<Longrightarrow> x < 4294967296 \<Longrightarrow> int_of_uint32 (uint32_of_int x) = x"
  by (transfer, simp add: int_word_uint) 

function power_p32 :: "uint32 \<Rightarrow> uint32 \<Rightarrow> uint32" where
  "power_p32 x n = (if n = 0 then 1 else
    let rec = power_p32 (mult_p32 x x) (shiftr n 1) in
    if n AND 1 = 0 then rec else mult_p32 rec x)"
  by pat_completeness auto

termination 
proof -
  {
    fix n :: uint32
    assume "n \<noteq> 0" 
    with int_of_uint32_ge_0[of n] int_of_uint32_0_iff[of n] have "int_of_uint32 n > 0" by auto
    hence "0 < int_of_uint32 n" "int_of_uint32 n div 2 < int_of_uint32 n" by auto
  } note * = this
  show ?thesis
    by (relation "measure (\<lambda> (x,n). nat (int_of_uint32 n))", auto simp: int_of_uint32_shift *) 
qed

text \<open>In experiments with Berlekamp-factorization (where the prime $p$ is usually small),
  it turned out that taking the below implementation of inverse via exponentiation
  is faster than the one based on the extended Euclidean algorithm.\<close>

definition inverse_p32 :: "uint32 \<Rightarrow> uint32" where
  "inverse_p32 x = (if x = 0 then 0 else power_p32 x (p - 2))"

definition divide_p32 :: "uint32 \<Rightarrow> uint32 \<Rightarrow> uint32"  where
  "divide_p32 x y = mult_p32 x (inverse_p32 y)"

definition finite_field_ops32 :: "uint32 arith_ops_record" where
  "finite_field_ops32 \<equiv> Arith_Ops_Record
      0
      1
      plus_p32
      mult_p32
      minus_p32
      uminus_p32
      divide_p32
      inverse_p32
      (\<lambda> x y . if y = 0 then x else 0)
      (\<lambda> x . if x = 0 then 0 else 1)
      (\<lambda> x . x)
      uint32_of_int
      int_of_uint32
      (\<lambda> x. 0 \<le> x \<and> x < p)"
end 

lemma shiftr_uint32_code [code_unfold]: "shiftr x 1 = (uint32_shiftr x 1)"
  unfolding shiftr_uint32_code using integer_of_nat_1 by auto

(* ******************************************************************************** *)
subsubsection \<open>Transfer Relation\<close>
locale mod_ring_locale =
  fixes p :: int and ty :: "'a :: nontriv itself"
  assumes p: "p = int CARD('a)"
begin
lemma nat_p: "nat p = CARD('a)" unfolding p by simp

definition mod_ring_rel :: "int \<Rightarrow> 'a mod_ring \<Rightarrow> bool" where
  "mod_ring_rel x x' = (x = to_int_mod_ring x')"

lemma to_int_mod_ring_inj: "to_int_mod_ring x = to_int_mod_ring y \<Longrightarrow> x = y"
  using injD[OF inj_to_int_mod_ring] .

(* domain transfer rules *)
lemma Domainp_mod_ring_rel [transfer_domain_rule]:
  "Domainp (mod_ring_rel) = (\<lambda> v. v \<in> {0 ..< p})"
proof -
  {
    fix v :: int
    assume *: "0 \<le> v" "v < p"
    have "Domainp mod_ring_rel v"
    proof
      show "mod_ring_rel v (of_int_mod_ring v)" unfolding mod_ring_rel_def using * p by auto
    qed
  } note * = this
  show ?thesis
    by (intro ext iffI, insert range_to_int_mod_ring[where 'a = 'a] *, auto simp: mod_ring_rel_def p)
qed

(* left/right/bi-unique *)
lemma bi_unique_mod_ring_rel [transfer_rule]:
  "bi_unique mod_ring_rel" "left_unique mod_ring_rel" "right_unique mod_ring_rel"
  unfolding mod_ring_rel_def bi_unique_def left_unique_def right_unique_def
  using to_int_mod_ring_inj by auto

(* left/right-total *)
lemma right_total_mod_ring_rel [transfer_rule]: "right_total mod_ring_rel"
  unfolding mod_ring_rel_def right_total_def by simp


(* ************************************************************************************ *)
subsubsection \<open>Transfer Rules\<close>

(* 0 / 1 *)
lemma mod_ring_0[transfer_rule]: "mod_ring_rel 0 0" unfolding mod_ring_rel_def by simp
lemma mod_ring_1[transfer_rule]: "mod_ring_rel 1 1" unfolding mod_ring_rel_def by simp

(* addition *)
lemma plus_p_mod_def: assumes x: "x \<in> {0 ..< p}" and y: "y \<in> {0 ..< p}"
  shows "plus_p p x y = ((x + y) mod p)"
proof (cases "p \<le> x + y")
  case False
  thus ?thesis using x y unfolding plus_p_def Let_def by auto
next
  case True
  from True x y have *: "p > 0" "0 \<le> x + y - p" "x + y - p < p" by auto
  from True have id: "plus_p p x y = x + y - p" unfolding plus_p_def by auto
  show ?thesis unfolding id using * using mod_pos_pos_trivial by fastforce
qed

lemma mod_ring_plus[transfer_rule]: "(mod_ring_rel ===> mod_ring_rel ===> mod_ring_rel) (plus_p p) (op +)"
proof -
  {
    fix x y :: "'a mod_ring"
    have "plus_p p (to_int_mod_ring x) (to_int_mod_ring y) = to_int_mod_ring (x + y)"
      by (transfer, subst plus_p_mod_def, auto, auto simp: p)
  } note * = this
  show ?thesis
    by (intro rel_funI, auto simp: mod_ring_rel_def *)
qed

(* subtraction *)
lemma minus_p_mod_def: assumes x: "x \<in> {0 ..< p}" and y: "y \<in> {0 ..< p}"
  shows "minus_p p x y = ((x - y) mod p)"
proof (cases "x - y < 0")
  case False
  thus ?thesis using x y unfolding minus_p_def Let_def by auto
next
  case True
  from True x y have *: "p > 0" "0 \<le> x - y + p" "x - y + p < p" by auto
  from True have id: "minus_p p x y = x - y + p" unfolding minus_p_def by auto
  show ?thesis unfolding id using * using mod_pos_pos_trivial by fastforce
qed

lemma mod_ring_minus[transfer_rule]: "(mod_ring_rel ===> mod_ring_rel ===> mod_ring_rel) (minus_p p) (op -)"
proof -
  {
    fix x y :: "'a mod_ring"
    have "minus_p p (to_int_mod_ring x) (to_int_mod_ring y) = to_int_mod_ring (x - y)"
      by (transfer, subst minus_p_mod_def, auto simp: p)
  } note * = this
  show ?thesis
    by (intro rel_funI, auto simp: mod_ring_rel_def *)
qed

(* unary minus *)
lemma mod_ring_uminus[transfer_rule]: "(mod_ring_rel ===> mod_ring_rel) (uminus_p p) uminus"
proof -
  {
    fix x :: "'a mod_ring"
    have "uminus_p p (to_int_mod_ring x) = to_int_mod_ring (uminus x)"
      by (transfer, auto simp: uminus_p_def p)
  } note * = this
  show ?thesis
    by (intro rel_funI, auto simp: mod_ring_rel_def *)
qed

(* multiplication *)
lemma mod_ring_mult[transfer_rule]: "(mod_ring_rel ===> mod_ring_rel ===> mod_ring_rel) (mult_p p) (op *)"
proof -
  {
    fix x y :: "'a mod_ring"
    have "mult_p p (to_int_mod_ring x) (to_int_mod_ring y) = to_int_mod_ring (x * y)"
      by (transfer, auto simp: mult_p_def p)
  } note * = this
  show ?thesis
    by (intro rel_funI, auto simp: mod_ring_rel_def *)
qed

(* equality *)
lemma mod_ring_eq[transfer_rule]: "(mod_ring_rel ===> mod_ring_rel ===> op =) (op =) (op =)"
  by (intro rel_funI, auto simp: mod_ring_rel_def to_int_mod_ring_inj)

(* power *)
lemma mod_ring_power[transfer_rule]: "(mod_ring_rel ===> op = ===> mod_ring_rel) (power_p p) (op ^)"
proof (intro rel_funI, clarify, unfold binary_power[symmetric], goal_cases)
  fix x y n
  assume xy: "mod_ring_rel x y"
  from xy show "mod_ring_rel (power_p p x n) (binary_power y n)"
  proof (induct y n arbitrary: x rule: binary_power.induct)
    case (1 x n y)
    note 1(2)[transfer_rule]
    show ?case
    proof (cases "n = 0")
      case True
      thus ?thesis by (simp add: mod_ring_1)
    next
      case False
      obtain d r where id: "Divides.divmod_nat n 2 = (d,r)" by force
      let ?int = "power_p p (mult_p p y y) d"
      let ?gfp = "binary_power (x * x) d"
      from False have id': "?thesis = (mod_ring_rel
         (if r = 0 then ?int else mult_p p ?int y)
         (if r = 0 then ?gfp else ?gfp * x))"
        unfolding power_p.simps[of _ _ n] binary_power.simps[of _ n] Let_def id split by simp
      have [transfer_rule]: "mod_ring_rel ?int ?gfp"
        by (rule 1(1)[OF False refl id[symmetric]], transfer_prover)
      show ?thesis unfolding id' by transfer_prover
    qed
  qed
qed

declare power_p.simps[simp del]

end

locale prime_field = mod_ring_locale p ty for p and ty :: "'a :: prime_card itself"
begin

lemma prime: "prime p" unfolding p using prime_card[where 'a = 'a] by simp

(* mod *)
lemma mod_ring_mod[transfer_rule]:
 "(mod_ring_rel ===> mod_ring_rel ===> mod_ring_rel) ((\<lambda> x y. if y = 0 then x else 0)) (op mod)"
proof -
  {
    fix x y :: "'a mod_ring"
    have "(if to_int_mod_ring y = 0 then to_int_mod_ring x else 0) = to_int_mod_ring (x mod y)"
      unfolding modulo_mod_ring_def by auto
  } note * = this
  show ?thesis
    by (intro rel_funI, auto simp: mod_ring_rel_def *[symmetric])
qed

(* normalize *)
lemma mod_ring_normalize[transfer_rule]: "(mod_ring_rel ===> mod_ring_rel) ((\<lambda> x. if x = 0 then 0 else 1)) normalize"
proof -
  {
    fix x :: "'a mod_ring"
    have "(if to_int_mod_ring x = 0 then 0 else 1) = to_int_mod_ring (normalize x)"
      unfolding normalize_mod_ring_def by auto
  } note * = this
  show ?thesis
    by (intro rel_funI, auto simp: mod_ring_rel_def *[symmetric])
qed

(* unit_factor *)
lemma mod_ring_unit_factor[transfer_rule]: "(mod_ring_rel ===> mod_ring_rel) (\<lambda> x. x) unit_factor"
proof -
  {
    fix x :: "'a mod_ring"
    have "to_int_mod_ring x = to_int_mod_ring (unit_factor x)"
      unfolding unit_factor_mod_ring_def by auto
  } note * = this
  show ?thesis
    by (intro rel_funI, auto simp: mod_ring_rel_def *[symmetric])
qed

(* inverse *)
lemma p2: "p \<ge> 2" using prime_ge_2_int[OF prime] by auto
lemma p2_ident: "int (CARD('a) - 2) = p - 2" using p2 unfolding p by simp

lemma mod_ring_inverse[transfer_rule]: "(mod_ring_rel ===> mod_ring_rel) (inverse_p p) inverse"
proof (intro rel_funI)
  fix x y
  assume [transfer_rule]: "mod_ring_rel x y"
  show "mod_ring_rel (inverse_p p x) (inverse y)"
    unfolding inverse_p_def inverse_mod_ring_def
    apply (transfer_prover_start)
    apply (transfer_step)+
    apply (unfold p2_ident)
    apply (rule refl)
    done
qed

(* division *)
lemma mod_ring_divide[transfer_rule]: "(mod_ring_rel ===> mod_ring_rel ===> mod_ring_rel)
  (divide_p p) (op /)"
  unfolding divide_p_def[abs_def] divide_mod_ring_def[abs_def] inverse_mod_ring_def[symmetric]
  by transfer_prover

lemma mod_ring_rel_unsafe: assumes "x < CARD('a)"
  shows "mod_ring_rel (int x) (of_nat x)" "0 < x \<Longrightarrow> of_nat x \<noteq> (0 :: 'a mod_ring)"
proof -
  have id: "of_nat x = (of_int (int x) :: 'a mod_ring)" by simp
  show "mod_ring_rel (int x) (of_nat x)" "0 < x \<Longrightarrow> of_nat x \<noteq> (0 :: 'a mod_ring)" unfolding id
  unfolding mod_ring_rel_def
  proof (auto simp add: assms of_int_of_int_mod_ring)
    assume "0 < x" with assms
    have "of_int_mod_ring (int x) \<noteq> (0 :: 'a mod_ring)"
      by (metis (no_types) less_imp_of_nat_less less_irrefl of_nat_0_le_iff of_nat_0_less_iff to_int_mod_ring_0 to_int_mod_ring_of_int_mod_ring)
    thus "of_int_mod_ring (int x) = (0 :: 'a mod_ring) \<Longrightarrow> False" by blast
  qed
qed

lemma finite_field_ops: "field_ops (finite_field_ops p) mod_ring_rel"
  by (unfold_locales, auto simp:
  finite_field_ops_def
  bi_unique_mod_ring_rel
  right_total_mod_ring_rel
  mod_ring_divide
  mod_ring_plus
  mod_ring_minus
  mod_ring_uminus
  mod_ring_inverse
  mod_ring_mod
  mod_ring_unit_factor
  mod_ring_normalize
  mod_ring_mult
  mod_ring_eq
  mod_ring_0
  mod_ring_1
  Domainp_mod_ring_rel)

end

text \<open>Once we have proven the soundness of the implementation, we do not care any longer
  that @{typ "'a mod_ring"} has been defined internally via lifting. Disabling the transfer-rules
  will hide the internal definition in further applications of transfer.\<close>
lifting_forget mod_ring.lifting

text \<open>For soundness of the 32-bit implementation, we mainly prove that this implementation
  implements the int-based implementation of GF(p).\<close>
context prime_field
begin

context fixes pp :: "uint32" 
  assumes ppp: "p = int_of_uint32 pp" 
  and small: "p \<le> 65535" 
begin

lemmas uint_simps = 
  int_of_uint32_0
  int_of_uint32_plus 
  int_of_uint32_minus
  int_of_uint32_mult
  

definition urel :: "uint32 \<Rightarrow> int \<Rightarrow> bool" where "urel x y = (y = int_of_uint32 x \<and> y < p)" 

definition mod_ring_rel32 :: "uint32 \<Rightarrow> 'a mod_ring \<Rightarrow> bool" where
  "mod_ring_rel32 x y = (\<exists> z. urel x z \<and> mod_ring_rel z y)" 

lemma urel_0: "urel 0 0" unfolding urel_def using p2 by (simp, transfer, simp)

lemma urel_1: "urel 1 1" unfolding urel_def using p2 by (simp, transfer, simp)

lemma le_int_of_uint32: "(x \<le> y) = (int_of_uint32 x \<le> int_of_uint32 y)" 
  by (transfer, simp add: word_le_def)

lemma urel_plus: assumes "urel x y" "urel x' y'"
  shows "urel (plus_p32 pp x x') (plus_p p y y')"
proof -    
  let ?x = "int_of_uint32 x" 
  let ?x' = "int_of_uint32 x'" 
  let ?p = "int_of_uint32 pp" 
  from assms int_of_uint32_ge_0 have id: "y = ?x" "y' = ?x'" 
    and rel: "0 \<le> ?x" "?x < p" 
      "0 \<le> ?x'" "?x' \<le> p" unfolding urel_def by auto
  have le: "(pp \<le> x + x') = (?p \<le> ?x + ?x')" unfolding le_int_of_uint32
    using rel small by (auto simp: uint_simps)
  show ?thesis
  proof (cases "?p \<le> ?x + ?x'")
    case True
    hence True: "(?p \<le> ?x + ?x') = True" by simp
    show ?thesis unfolding id 
      using small rel unfolding plus_p32_def plus_p_def Let_def urel_def 
      unfolding ppp le True if_True
      using True by (auto simp: uint_simps)
  next
    case False
    hence False: "(?p \<le> ?x + ?x') = False" by simp
    show ?thesis unfolding id 
      using small rel unfolding plus_p32_def plus_p_def Let_def urel_def 
      unfolding ppp le False if_False
      using False by (auto simp: uint_simps)
  qed
qed
  
lemma urel_minus: assumes "urel x y" "urel x' y'"
  shows "urel (minus_p32 pp x x') (minus_p p y y')"
proof -    
  let ?x = "int_of_uint32 x" 
  let ?x' = "int_of_uint32 x'" 
  from assms int_of_uint32_ge_0 have id: "y = ?x" "y' = ?x'" 
    and rel: "0 \<le> ?x" "?x < p" 
      "0 \<le> ?x'" "?x' \<le> p" unfolding urel_def by auto
  have le: "(x' \<le> x) = (?x' \<le> ?x)" unfolding le_int_of_uint32
    using rel small by (auto simp: uint_simps)
  show ?thesis
  proof (cases "?x' \<le> ?x")
    case True
    hence True: "(?x' \<le> ?x) = True" by simp
    show ?thesis unfolding id 
      using small rel unfolding minus_p32_def minus_p_def Let_def urel_def 
      unfolding ppp le True if_True
      using True by (auto simp: uint_simps)
  next
    case False
    hence False: "(?x' \<le> ?x) = False" by simp
    show ?thesis unfolding id 
      using small rel unfolding minus_p32_def minus_p_def Let_def urel_def 
      unfolding ppp le False if_False
      using False by (auto simp: uint_simps)
  qed
qed

lemma urel_uminus: assumes "urel x y"
  shows "urel (uminus_p32 pp x) (uminus_p p y)"
proof -    
  let ?x = "int_of_uint32 x"  
  from assms int_of_uint32_ge_0 have id: "y = ?x" 
    and rel: "0 \<le> ?x" "?x < p" 
      unfolding urel_def by auto
  have le: "(x = 0) = (?x = 0)" unfolding int_of_uint32_0_iff
    using rel small by (auto simp: uint_simps)
  show ?thesis
  proof (cases "?x = 0")
    case True
    hence True: "(?x = 0) = True" by simp
    show ?thesis unfolding id 
      using small rel unfolding uminus_p32_def uminus_p_def Let_def urel_def 
      unfolding ppp le True if_True
      using True by (auto simp: uint_simps)
  next
    case False
    hence False: "(?x = 0) = False" by simp
    show ?thesis unfolding id 
      using small rel unfolding uminus_p32_def uminus_p_def Let_def urel_def 
      unfolding ppp le False if_False
      using False by (auto simp: uint_simps)
  qed
qed

lemma urel_mult: assumes "urel x y" "urel x' y'"
  shows "urel (mult_p32 pp x x') (mult_p p y y')"
proof -    
  let ?x = "int_of_uint32 x" 
  let ?x' = "int_of_uint32 x'" 
  from assms int_of_uint32_ge_0 have id: "y = ?x" "y' = ?x'" 
    and rel: "0 \<le> ?x" "?x < p" 
      "0 \<le> ?x'" "?x' < p" unfolding urel_def by auto
  from rel have "?x * ?x' < p * p" by (metis mult_strict_mono') 
  also have "\<dots> \<le> 65536 * 65536"
    by (rule mult_mono, insert p2 small, auto)
  finally have le: "?x * ?x' < 4294967296" by simp
  show ?thesis unfolding id
      using small rel unfolding mult_p32_def mult_p_def Let_def urel_def 
      unfolding ppp 
    by (auto simp: uint_simps, unfold int_of_uint32_mod int_of_uint32_mult, 
        subst mod_pos_pos_trivial[of _ 4294967296], insert le, auto)
qed

lemma urel_eq: assumes "urel x y" "urel x' y'" 
  shows "(x = x') = (y = y')" 
proof -    
  let ?x = "int_of_uint32 x" 
  let ?x' = "int_of_uint32 x'" 
  from assms int_of_uint32_ge_0 have id: "y = ?x" "y' = ?x'" 
    unfolding urel_def by auto
  show ?thesis unfolding id by (transfer, auto)
qed

lemma urel_normalize: 
assumes x: "urel x y"
shows "urel (if x = 0 then 0 else 1) (if y = 0 then 0 else 1)"
 unfolding urel_eq[OF x urel_0] using urel_0 urel_1 by auto

lemma urel_mod: 
assumes x: "urel x x'" and y: "urel y y'" 
shows "urel (if y = 0 then x else 0) (if y' = 0 then x' else 0)"
  unfolding urel_eq[OF y urel_0] using urel_0 x by auto 

lemma urel_power: "urel x x' \<Longrightarrow> urel y (int y') \<Longrightarrow> urel (power_p32 pp x y) (power_p p x' y')"
proof (induct x' y' arbitrary: x y rule: power_p.induct[of _ p])
  case (1 x' y' x y)
  note x = 1(2) note y = 1(3)
  show ?case
  proof (cases "y' = 0")
    case True
    hence y: "y = 0" using urel_eq[OF y urel_0] by auto
    show ?thesis unfolding y True by (simp add: power_p.simps urel_1)
  next
    case False
    hence id: "(y = 0) = False" "(y' = 0) = False" using urel_eq[OF y urel_0] by auto
    obtain d' r' where dr': "Divides.divmod_nat y' 2 = (d',r')" by force
    from divmod_nat_div_mod[of y' 2, unfolded dr']
    have r': "r' = y' mod 2" and d': "d' = y' div 2" by auto
    have aux: "\<And> y'. int (y' mod 2) = int y' mod 2" by presburger
    have "urel (y AND 1) r'" unfolding r' using y unfolding urel_def using small
      unfolding ppp by (transfer, auto simp: uint_and int_and_1, auto simp: aux) 
    from urel_eq[OF this urel_0]     
    have rem: "(y AND 1 = 0) = (r' = 0)" by simp
    have div: "urel (shiftr y 1) (int d')" unfolding d' using y unfolding urel_def using small
      unfolding ppp 
      by (transfer, auto simp: shiftr_div_2n) 
    note IH = 1(1)[OF False refl dr'[symmetric] urel_mult[OF x x] div]
    show ?thesis unfolding power_p.simps[of _ _ "y'"] power_p32.simps[of _ _ y] dr' id if_False rem
      using IH urel_mult[OF IH x] by (auto simp: Let_def)
  qed
qed
  

lemma urel_inverse: assumes x: "urel x x'" 
  shows "urel (inverse_p32 pp x) (inverse_p p x')" 
proof -
  have p: "urel (pp - 2) (int (nat (p - 2)))" using p2 small unfolding urel_def unfolding ppp
    by (transfer, auto simp: uint_word_ariths)
  show ?thesis
    unfolding inverse_p32_def inverse_p_def urel_eq[OF x urel_0] using urel_0 urel_power[OF x p]
    by auto
qed

lemma mod_ring_0_32: "mod_ring_rel32 0 0"
  using urel_0 mod_ring_0 unfolding mod_ring_rel32_def by blast

lemma mod_ring_1_32: "mod_ring_rel32 1 1"
  using urel_1 mod_ring_1 unfolding mod_ring_rel32_def by blast

lemma mod_ring_uminus32: "(mod_ring_rel32 ===> mod_ring_rel32) (uminus_p32 pp) uminus"
  using urel_uminus mod_ring_uminus unfolding mod_ring_rel32_def rel_fun_def by blast

lemma mod_ring_plus32: "(mod_ring_rel32 ===> mod_ring_rel32 ===> mod_ring_rel32) (plus_p32 pp) (op +)"
  using urel_plus mod_ring_plus unfolding mod_ring_rel32_def rel_fun_def by blast

lemma mod_ring_minus32: "(mod_ring_rel32 ===> mod_ring_rel32 ===> mod_ring_rel32) (minus_p32 pp) (op -)"
  using urel_minus mod_ring_minus unfolding mod_ring_rel32_def rel_fun_def by blast

lemma mod_ring_mult32: "(mod_ring_rel32 ===> mod_ring_rel32 ===> mod_ring_rel32) (mult_p32 pp) (op *)"
  using urel_mult mod_ring_mult unfolding mod_ring_rel32_def rel_fun_def by blast

lemma mod_ring_normalize32: "(mod_ring_rel32 ===> mod_ring_rel32) (\<lambda>x. if x = 0 then 0 else 1) normalize" 
  using urel_normalize mod_ring_normalize  unfolding mod_ring_rel32_def rel_fun_def by blast

lemma mod_ring_mod32: "(mod_ring_rel32 ===> mod_ring_rel32 ===> mod_ring_rel32) (\<lambda>x y. if y = 0 then x else 0) op mod" 
  using urel_mod mod_ring_mod unfolding mod_ring_rel32_def rel_fun_def by blast

lemma mod_ring_unit_factor32: "(mod_ring_rel32 ===> mod_ring_rel32) (\<lambda>x. x) unit_factor" 
  using mod_ring_unit_factor unfolding mod_ring_rel32_def rel_fun_def by blast

lemma mod_ring_eq32: "(mod_ring_rel32 ===> mod_ring_rel32 ===> op =) op = op =" 
  using urel_eq mod_ring_eq unfolding mod_ring_rel32_def rel_fun_def by blast

lemma mod_ring_inverse32: "(mod_ring_rel32 ===> mod_ring_rel32) (inverse_p32 pp) inverse"
  using urel_inverse mod_ring_inverse unfolding mod_ring_rel32_def rel_fun_def by blast

lemma mod_ring_divide32: "(mod_ring_rel32 ===> mod_ring_rel32 ===> mod_ring_rel32) (divide_p32 pp) op /"
  using mod_ring_inverse32 mod_ring_mult32
  unfolding divide_p32_def divide_mod_ring_def inverse_mod_ring_def[symmetric]
    rel_fun_def by blast

lemma urel_inj: "urel x y \<Longrightarrow> urel x z \<Longrightarrow> y = z" 
  using urel_eq[of x y x z] by auto

lemma urel_inj': "urel x z \<Longrightarrow> urel y z \<Longrightarrow> x = y" 
  using urel_eq[of x z y z] by auto

lemma bi_unique_mod_ring_rel32:
  "bi_unique mod_ring_rel32" "left_unique mod_ring_rel32" "right_unique mod_ring_rel32"
  using bi_unique_mod_ring_rel urel_inj'
  unfolding mod_ring_rel32_def bi_unique_def left_unique_def right_unique_def
  by (auto simp: urel_def)  

lemma right_total_mod_ring_rel32: "right_total mod_ring_rel32"
  unfolding mod_ring_rel32_def right_total_def
proof 
  fix y :: "'a mod_ring" 
  from right_total_mod_ring_rel[unfolded right_total_def, rule_format, of y]
  obtain z where zy: "mod_ring_rel z y" by auto  
  hence zp: "0 \<le> z" "z < p" unfolding mod_ring_rel_def p using range_to_int_mod_ring[where 'a = 'a] by auto
  hence "urel (uint32_of_int z) z" unfolding urel_def using small unfolding ppp 
    by (auto simp: int_of_uint32_inv) 
  with zy show "\<exists> x z. urel x z \<and> mod_ring_rel z y" by blast
qed

lemma Domainp_mod_ring_rel32: "Domainp mod_ring_rel32 = (\<lambda>x. 0 \<le> x \<and> x < pp)"
proof 
  fix x
  show "Domainp mod_ring_rel32 x = (0 \<le> x \<and> x < pp)"   
    unfolding Domainp.simps
    unfolding mod_ring_rel32_def
  proof
    let ?i = "int_of_uint32" 
    assume *: "0 \<le> x \<and> x < pp"     
    hence "0 \<le> ?i x \<and> ?i x < p" using small unfolding ppp
      by (transfer, auto simp: word_less_def)
    hence "?i x \<in> {0 ..< p}" by auto
    with Domainp_mod_ring_rel
    have "Domainp mod_ring_rel (?i x)" by auto
    from this[unfolded Domainp.simps]
    obtain b where b: "mod_ring_rel (?i x) b" by auto
    show "\<exists>a b. x = a \<and> (\<exists>z. urel a z \<and> mod_ring_rel z b)" 
    proof (intro exI, rule conjI[OF refl], rule exI, rule conjI[OF _ b])
      show "urel x (?i x)" unfolding urel_def using small * unfolding ppp
        by (transfer, auto simp: word_less_def)
    qed
  next
    assume "\<exists>a b. x = a \<and> (\<exists>z. urel a z \<and> mod_ring_rel z b)" 
    then obtain b z where xz: "urel x z" and zb: "mod_ring_rel z b" by auto
    hence "Domainp mod_ring_rel z"  by auto
    with Domainp_mod_ring_rel have "0 \<le> z" "z < p" by auto
    with xz show "0 \<le> x \<and> x < pp" unfolding urel_def using small unfolding ppp
      by (transfer, auto simp: word_less_def)
  qed
qed

lemma finite_field_ops32: "field_ops (finite_field_ops32 pp) mod_ring_rel32"
  by (unfold_locales, auto simp:
  finite_field_ops32_def
  bi_unique_mod_ring_rel32
  right_total_mod_ring_rel32
  mod_ring_divide32
  mod_ring_plus32
  mod_ring_minus32
  mod_ring_uminus32
  mod_ring_inverse32
  mod_ring_mod32
  mod_ring_unit_factor32
  mod_ring_normalize32
  mod_ring_mult32
  mod_ring_eq32
  mod_ring_0_32
  mod_ring_1_32
  Domainp_mod_ring_rel32)

end
end

no_notation shiftr (infixl ">>" 55) (* to avoid conflict with bind *)
end