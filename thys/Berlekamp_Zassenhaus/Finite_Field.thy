(*
    Authors:      Jose Divasón
                  Sebastiaan Joosten
                  René Thiemann
                  Akihisa Yamada
*)
subsection {* Finite Rings *}

theory Finite_Field
imports 
  "~~/src/HOL/Number_Theory/Primes"
  "~~/src/HOL/Number_Theory/Residues"
  "../Containers/Set_Impl"
  Binary_Exponentiation
begin

typedef ('a::finite) mod_ring = "{0..<int CARD('a)}" by auto

setup_lifting type_definition_mod_ring

lemma CARD_mod_ring[simp]: "CARD('a mod_ring) = CARD('a::finite)" 
proof -
  have "card {y. \<exists>x\<in>{0..<int CARD('a)}. (y::'a mod_ring) = Abs_mod_ring x} = card {0..<int CARD('a)}"
  proof (rule bij_betw_same_card)
    have "inj_on Rep_mod_ring {y. \<exists>x\<in>{0..<int CARD('a)}. y = Abs_mod_ring x}"
      by (meson Rep_mod_ring_inject inj_onI)      
    moreover have "Rep_mod_ring ` {y. \<exists>x\<in>{0..<int CARD('a)}. (y::'a mod_ring) = Abs_mod_ring x} = {0..<int CARD('a)}"
    proof (auto simp add: image_def Rep_mod_ring_inject)
      fix xb show "0 \<le> Rep_mod_ring (Abs_mod_ring xb)" 
        using Rep_mod_ring atLeastLessThan_iff by blast 
      assume xb1: "0 \<le> xb" and xb2: "xb < int CARD('a)"
      thus " Rep_mod_ring (Abs_mod_ring xb) < int CARD('a)"
        by (metis Abs_mod_ring_inverse Rep_mod_ring atLeastLessThan_iff le_less_trans linear)
      have xb: "xb \<in> {0..<int CARD('a)}" using xb1 xb2 by simp
      show "\<exists>xa::'a mod_ring. (\<exists>x\<in>{0..<int CARD('a)}. xa = Abs_mod_ring x) \<and> xb = Rep_mod_ring xa"
      by (rule exI[of _ "Abs_mod_ring xb"], auto simp add: xb1 xb2, rule Abs_mod_ring_inverse[OF xb, symmetric])
    qed    
    ultimately show "bij_betw Rep_mod_ring
      {y. \<exists>x\<in>{0..<int CARD('a)}. (y::'a mod_ring) = Abs_mod_ring x} 
      {0..<int CARD('a)}"
      by (simp add: bij_betw_def)
  qed
  thus ?thesis
    unfolding type_definition.univ[OF type_definition_mod_ring]
    unfolding image_def by auto
qed

instance mod_ring :: (finite) finite 
proof (intro_classes)
  show "finite (UNIV::'a mod_ring set)" 
    unfolding type_definition.univ[OF type_definition_mod_ring]
    using finite by simp
qed


instantiation mod_ring :: (finite) equal
begin
lift_definition equal_mod_ring :: "'a mod_ring \<Rightarrow> 'a mod_ring \<Rightarrow> bool" is "op =" .
instance by (intro_classes, transfer, auto)
end

instantiation mod_ring :: (finite) comm_ring
begin

lift_definition plus_mod_ring :: "'a mod_ring \<Rightarrow> 'a mod_ring \<Rightarrow> 'a mod_ring" is
  "\<lambda> x y. (x + y) mod int (CARD('a))" by simp

lift_definition uminus_mod_ring :: "'a mod_ring \<Rightarrow> 'a mod_ring" is
  "\<lambda> x. if x = 0 then 0 else int (CARD('a)) - x" by simp

lift_definition minus_mod_ring :: "'a mod_ring \<Rightarrow> 'a mod_ring \<Rightarrow> 'a mod_ring" is
  "\<lambda> x y. (x - y) mod int (CARD('a))" by simp

lift_definition times_mod_ring :: "'a mod_ring \<Rightarrow> 'a mod_ring \<Rightarrow> 'a mod_ring" is
  "\<lambda> x y. (x * y) mod int (CARD('a))" by simp

lift_definition zero_mod_ring :: "'a mod_ring" is 0 by simp

instance
proof
  fix a b c::"'a mod_ring"
  show "a + b + c = a + (b + c)" by (transfer, unfold atLeastLessThan_iff, presburger)
  show "a + b = b + a" by (transfer, unfold atLeastLessThan_iff, presburger)
  show "0 + a = a"  using mod_pos_pos_trivial by(transfer, auto)
  show "- a + a = 0" by(transfer, auto)
  note mod_add_right_eq[symmetric, simp] mod_mult_right_eq[symmetric, simp]
  show "a - b = a + - b" by (transfer, subst if_distrib[of "\<lambda>x. (_ + x) mod _"], subst(2) mod_add_eq, auto)
  show "a * b * c = a * (b * c)" by (transfer, auto simp: ac_simps)
  show "(a + b) * c = a * c + b * c" by (transfer, auto simp: ac_simps distrib_left)
  show "a * b = b * a" by (transfer, auto simp:ac_simps)
qed
end

lift_definition to_int_mod_ring :: "'a::finite mod_ring \<Rightarrow> int" is "\<lambda> x. x" .

lift_definition of_int_mod_ring :: "int \<Rightarrow> 'a::finite mod_ring" is
  "\<lambda> x. x mod int (CARD('a))" by simp

lemma to_int_mod_ring_0[simp]: "to_int_mod_ring 0 = 0" by (transfer, simp)
lemma int_nat_card[simp]: "int (nat CARD('a::finite)) = CARD('a)" by auto
lemma of_int_mod_ring_0[simp]: "of_int_mod_ring 0 = 0" by (transfer, auto)

lemma of_int_mod_ring_to_int_mod_ring[simp]:
  "of_int_mod_ring (to_int_mod_ring x) = x" by (transfer, auto)

lemma to_int_mod_ring_of_int_mod_ring[simp]: "0 \<le> x \<Longrightarrow> x < int CARD('a :: finite) \<Longrightarrow>
  to_int_mod_ring (of_int_mod_ring x :: 'a mod_ring) = x"
  by (transfer, auto)

lemma inj_to_int_mod_ring[simp]: "inj to_int_mod_ring" unfolding inj_on_def
  by transfer auto

lemma range_to_int_mod_ring:
  "range (to_int_mod_ring :: ('a :: finite mod_ring \<Rightarrow> int)) = {0 ..< CARD('a)}"
  apply (intro equalityI subsetI)
  apply (elim rangeE, transfer, force)
  by (auto intro!: range_eqI to_int_mod_ring_of_int_mod_ring[symmetric])

subsection {* Nontrivial Finite Rings *}

class nontriv = assumes nontriv: "CARD('a) > 1"

subclass(in nontriv) finite by(intro_classes,insert nontriv,auto intro:card_ge_0_finite)

instantiation mod_ring :: (nontriv) comm_ring_1
begin

lift_definition one_mod_ring :: "'a mod_ring" is 1 using nontriv[where ?'a='a] by auto

instance by (intro_classes; transfer, simp)

end

lemma of_nat_of_int_mod_ring[code_unfold]: "of_nat = of_int_mod_ring o int"
proof (rule ext, unfold o_def)
  show "of_nat n = of_int_mod_ring (int n)" for n
  proof (induct n)
    case (Suc n)
    show ?case by (unfold of_nat_Suc Suc, transfer, presburger)
  qed simp
qed

lemma to_int_mod_ring_1[simp]: "to_int_mod_ring 1 = 1" by (transfer, simp)

lemma of_nat_card_eq_0[simp]: "(of_nat (CARD('a::nontriv)) :: 'a mod_ring) = 0"
  by (unfold of_nat_of_int_mod_ring, transfer, auto)

lemma of_int_of_int_mod_ring[code_unfold]: "of_int = of_int_mod_ring"
proof (rule ext)
  fix x :: int
  obtain n1 n2 where x: "x = int n1 - int n2" by (rule int_diff_cases)
  show "of_int x = of_int_mod_ring x"
    unfolding x of_int_diff of_int_of_nat_eq of_nat_of_int_mod_ring o_def
    by (transfer, simp add: mod_diff_right_eq[symmetric] mod_diff_left_eq[symmetric])
qed

unbundle lifting_syntax

lemma pcr_mod_ring_to_int_mod_ring: "pcr_mod_ring = (\<lambda>x y. x = to_int_mod_ring y)"
 unfolding mod_ring.pcr_cr_eq unfolding cr_mod_ring_def to_int_mod_ring.rep_eq ..

lemma [transfer_rule]:
  "(op = ===> pcr_mod_ring) (\<lambda> x. int x mod int (CARD('a :: nontriv))) (of_nat :: nat \<Rightarrow> 'a mod_ring)"
  by (intro rel_funI, unfold pcr_mod_ring_to_int_mod_ring of_nat_of_int_mod_ring, transfer, auto)

lemma [transfer_rule]:
  "(op = ===> pcr_mod_ring) (\<lambda> x. x mod int (CARD('a :: nontriv))) (of_int :: int \<Rightarrow> 'a mod_ring)"
  by (intro rel_funI, unfold pcr_mod_ring_to_int_mod_ring of_int_of_int_mod_ring, transfer, auto)

lemma one_mod_card[simp]: "1 mod CARD('a::nontriv) = 1" 
  using Divides.mod_less prime_def nontriv by blast

lemma one_mod_card_int[simp]: "1 mod int CARD('a::nontriv) = 1" 
  using one_mod_card 
  by (metis Divides.transfer_int_nat_functions(2) of_nat_1)

lemma pow_mod_ring_transfer[transfer_rule]:
  "(pcr_mod_ring ===> op = ===> pcr_mod_ring) 
   (\<lambda>a::int. \<lambda>n. a^n mod CARD('a::nontriv)) (op ^::'a mod_ring \<Rightarrow> nat \<Rightarrow> 'a mod_ring)"
unfolding pcr_mod_ring_to_int_mod_ring
proof (intro rel_funI,simp)
  fix x::"'a mod_ring" and n
  show "to_int_mod_ring x ^ n mod int CARD('a) = to_int_mod_ring (x ^ n)"
  proof (induct n)
    case 0
    thus ?case by auto
  next
    case (Suc n)
    have "to_int_mod_ring (x ^ Suc n) = to_int_mod_ring (x * x ^ n)" by auto
    also have "... = to_int_mod_ring x * to_int_mod_ring (x ^ n) mod CARD('a)"
      unfolding to_int_mod_ring_def using times_mod_ring.rep_eq by auto
    also have "... = to_int_mod_ring x * (to_int_mod_ring x ^ n mod CARD('a)) mod CARD('a)"
      using Suc.hyps by auto
    also have "... = to_int_mod_ring x ^ Suc n mod int CARD('a)"
      by (simp add: zmod_simps(3))
    finally show ?case ..
  qed
qed

lemma dvd_mod_ring_transfer[transfer_rule]:
"((pcr_mod_ring :: int \<Rightarrow> 'a :: nontriv mod_ring \<Rightarrow> bool) ===>
  (pcr_mod_ring :: int \<Rightarrow> 'a mod_ring \<Rightarrow> bool) ===> op =)
  (\<lambda> i j. \<exists>k \<in> {0..<int CARD('a)}. j = i * k mod int CARD('a)) (op dvd)"
proof (unfold pcr_mod_ring_to_int_mod_ring, intro rel_funI iffI)
  fix x y :: "'a mod_ring" and i j
  assume i: "i = to_int_mod_ring x" and j: "j = to_int_mod_ring y"
  { assume "x dvd y"
    then obtain z where "y = x * z" by (elim dvdE, auto)
    then have "j = i * to_int_mod_ring z mod CARD('a)" by (unfold i j, transfer)
    with range_to_int_mod_ring
    show "\<exists>k \<in> {0..<int CARD('a)}. j = i * k mod CARD('a)" by auto
  }
  assume "\<exists>k \<in> {0..<int CARD('a)}. j = i * k mod CARD('a)"
  then obtain k where k: "k \<in> {0..<int CARD('a)}" and dvd: "j = i * k mod CARD('a)" by auto
  from k have "to_int_mod_ring (of_int k :: 'a mod_ring) = k" by (transfer, auto)
  also from dvd have "j = i * ... mod CARD('a)" by auto
  finally have "y = x * (of_int k :: 'a mod_ring)" unfolding i j using k by (transfer, auto)
  then show "x dvd y" by auto
qed

lemma Rep_mod_ring_mod[simp]: "Rep_mod_ring (a :: 'a :: nontriv mod_ring) mod CARD('a) = Rep_mod_ring a"
  using Rep_mod_ring[where 'a = 'a] by auto

subsection {* Finite Fields *}

text {* When the domain is prime, the ring becomes a field *}

class prime_card = assumes prime_card: "prime (CARD('a))"
begin
lemma prime_card_int: "prime (int (CARD('a)))" using prime_card by auto

subclass nontriv using prime_card prime_gt_1_nat by (intro_classes,auto)
end

instantiation mod_ring :: (prime_card) field
begin
 
definition inverse_mod_ring :: "'a mod_ring \<Rightarrow> 'a mod_ring" where
  "inverse_mod_ring x = (if x = 0 then 0 else x ^ (nat (CARD('a) - 2)))"

definition divide_mod_ring :: "'a mod_ring \<Rightarrow> 'a mod_ring \<Rightarrow> 'a mod_ring"  where
  "divide_mod_ring x y = x * ((\<lambda>c. if c = 0 then 0 else c ^ (nat (CARD('a) - 2))) y)" 

instance
proof
  fix a b c::"'a mod_ring"
  show "inverse 0 = (0::'a mod_ring)" by (simp add: inverse_mod_ring_def)
  show "a div b = a * inverse b" 
    unfolding inverse_mod_ring_def by (transfer', simp add: divide_mod_ring_def)
  show "a \<noteq> 0 \<Longrightarrow> inverse a * a = 1"
  proof (unfold inverse_mod_ring_def, transfer)
    let ?p="CARD('a)"
    fix x assume x: "x \<in> {0..<int CARD('a)}" and x0: "x \<noteq> 0"
    have p0': "0\<le>?p" by auto
    have p_not_dvd_x: "\<not> ?p dvd x"
      using x x0 zdvd_imp_le by fastforce
    have rw: "x ^ nat (int (?p - 2)) * x = x ^ nat (?p - 1)"
    proof -
      have p2: "0 \<le> int (?p-2)" using x by simp
      have card_rw: "(CARD('a) - Suc 0) = nat (1 + int (CARD('a) - 2))" 
        unfolding transfer_int_nat_numerals(2) nat_int_add 
        using nat_eq_iff x x0 by auto
      have "x ^ nat (?p - 2)*x = x ^ (Suc (nat (?p - 2)))" by simp
      also have "... = x ^ (nat (?p - 1))"
        using Suc_nat_eq_nat_zadd1[OF p2] card_rw by auto
      finally show ?thesis .
    qed
    have "x ^ (CARD('a) - 2) mod CARD('a) * x mod CARD('a) 
      = (x ^ nat (CARD('a) - 2) * x) mod CARD('a)" by (simp add: zmod_simps)
    also have "... =  (x ^ nat (?p - 1) mod ?p)" unfolding rw by simp
    also have "... = (x ^ (nat ?p - 1) mod ?p)" using p0' by (simp add: nat_diff_distrib')
    also have "... = 1" using fermat_theorem[OF prime_card_int p_not_dvd_x] by (auto simp: cong_int_def)
    finally show "(if x = 0 then 0 else x ^ nat (int (CARD('a) - 2)) mod CARD('a)) * x mod CARD('a) = 1"
      using x0 by auto
  qed
qed
end

instantiation mod_ring :: (prime_card) euclidean_ring
begin

definition modulo_mod_ring :: "'a mod_ring \<Rightarrow> 'a mod_ring \<Rightarrow> 'a mod_ring" where "modulo_mod_ring x y = (if y = 0 then x else 0)"
definition normalize_mod_ring :: "'a mod_ring \<Rightarrow> 'a mod_ring" where "normalize_mod_ring x = (if x = 0 then 0 else 1)" 
definition unit_factor_mod_ring :: "'a mod_ring \<Rightarrow> 'a mod_ring" where "unit_factor_mod_ring x = x" 
definition euclidean_size_mod_ring :: "'a mod_ring \<Rightarrow> nat" where "euclidean_size_mod_ring x = (if x = 0 then 0 else 1)" 

instance
proof (intro_classes)
  fix a :: "'a mod_ring" show "a \<noteq> 0 \<Longrightarrow> unit_factor a dvd 1"
    unfolding dvd_def unit_factor_mod_ring_def by (intro exI[of _ "inverse a"], auto)
qed (auto simp: normalize_mod_ring_def unit_factor_mod_ring_def modulo_mod_ring_def
     euclidean_size_mod_ring_def field_simps)
end

instantiation mod_ring :: (prime_card) euclidean_ring_gcd
begin

definition gcd_mod_ring :: "'a mod_ring \<Rightarrow> 'a mod_ring \<Rightarrow> 'a mod_ring" where "gcd_mod_ring = gcd_eucl"
definition lcm_mod_ring :: "'a mod_ring \<Rightarrow> 'a mod_ring \<Rightarrow> 'a mod_ring" where "lcm_mod_ring = lcm_eucl"
definition Gcd_mod_ring :: "'a mod_ring set \<Rightarrow> 'a mod_ring" where "Gcd_mod_ring = Gcd_eucl"
definition Lcm_mod_ring :: "'a mod_ring set \<Rightarrow> 'a mod_ring" where "Lcm_mod_ring = Lcm_eucl"

instance by (intro_classes, auto simp: gcd_mod_ring_def lcm_mod_ring_def Gcd_mod_ring_def Lcm_mod_ring_def)
end

lemma surj_of_nat_mod_ring: "\<exists> i. i < CARD('a :: prime_card) \<and> (x :: 'a mod_ring) = of_nat i" 
  by (rule exI[of _ "nat (to_int_mod_ring x)"], unfold of_nat_of_int_mod_ring o_def,
  subst nat_0_le, transfer, simp, simp, transfer, auto) 
  
lemma inj_to_int_mod_ring_point: "to_int_mod_ring x = to_int_mod_ring y \<Longrightarrow> x = y" by (transfer, auto)

lemma to_int_mod_ring_zero[simp]: "(to_int_mod_ring x = 0) = (x = 0)" by (transfer, auto)

lemma to_int_mod_ring_one[simp]: "(to_int_mod_ring x = 1) = (x = 1)" by (transfer, auto)

lemma of_nat_0_mod_ring_dvd: assumes x: "of_nat x = (0 :: 'a ::prime_card mod_ring)"
  shows "CARD('a) dvd x" 
proof -
  let ?x = "of_nat x :: int" 
  from x have "of_int_mod_ring ?x = (0 :: 'a mod_ring)" by (fold of_int_of_int_mod_ring, simp)
  hence "?x mod CARD('a) = 0" by (transfer, auto)
  hence "x mod CARD('a) = 0" by presburger
  thus ?thesis unfolding mod_eq_0_iff_dvd .
qed

end
