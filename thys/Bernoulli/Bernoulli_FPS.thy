(*  
  File:       Bernoulli_FPS.thy
  Author:     Manuel Eberl <eberlm@in.tum.de> 

  Connection of Bernoulli numbers to formal power series; proof B_n = 0 for odd n > 1;
  Akiyama-Tanigawa algorithm.
*)
section \<open>Connection of Bernoulli numbers to formal power series\<close>

theory Bernoulli_FPS
  imports 
    Bernoulli 
    "~~/src/HOL/Library/Formal_Power_Series"
    "~~/src/HOL/Library/Stirling"
begin
  
text \<open>
  In the following, we will prove the correctness of the 
  Akiyama--Tanigawa algorithm~\cite{kaneko2000}, which is a simple algorithm for computing 
  Bernoulli numbers that was discovered by Akiyama and Tanigawa~\cite{aki_tani1999} essentially 
  as a by-product of their studies of the Euler--Zagier multiple zeta function. The algorithm 
  is based on a number triangle (similar to Pascal's triangle) in which the Bernoulli numbers 
  are the leftmost diagonal.

  While the algorithm itself is quite simple, proving it correct is not entirely trivial.
  We will use generating functions and Stirling numbers, mostly following the presentation by
  Kaneko~\cite{kaneko2000}.
\<close>

subsection \<open>General facts about formal power series\<close>
  
(* TODO Move *)
lemma fps_compose_uminus': 
  "fps_compose f (-X :: 'a :: comm_ring_1 fps) = Abs_fps (\<lambda>n. (-1)^n * f $ n)"
  using fps_compose_linear[of f "-1"] 
  by (simp only: fps_const_neg [symmetric] fps_const_1_eq_1) simp

lemma X_dvd_L [simp]: "X dvd L c"
proof -
  have "L c = X * Abs_fps (\<lambda>n. (-1) ^ n / (of_nat (Suc n) * c))"
    by (intro fps_ext) (auto simp: L_def of_nat_diff)
  thus ?thesis by simp
qed

lemma fps_compose_E_linear [simp]: "E (d::'a::field_char_0) oo (fps_const c * X) = E (c * d)"
  by (simp add: fps_compose_linear E_def fps_eq_iff power_mult_distrib)
  
lemma fps_compose_E1_minus [simp]: "fps_compose (E c) (-X) = E (-c :: 'a :: field_char_0)"
  using fps_compose_E_linear[of c "-1 :: 'a"] 
  unfolding fps_const_neg [symmetric] fps_const_1_eq_1 by simp

lemma E_eq_iff [simp]: "E c = E d \<longleftrightarrow> c = (d :: 'a :: field_char_0)"
proof
  assume "E c = E d"
  from arg_cong[of _ _ "\<lambda>F. F $ 1", OF this] show "c = d" by simp
qed simp_all

lemma E_eq_fps_const_iff [simp]: "E (c :: 'a :: field_char_0) = fps_const c' \<longleftrightarrow> c = 0 \<and> c' = 1"
proof
  assume "c = 0 \<and> c' = 1"
  thus "E c = fps_const c'" by (auto simp: fps_eq_iff)
next
  assume "E c = fps_const c'"
  from arg_cong[of _ _ "\<lambda>F. F $ 1", OF this] arg_cong[of _ _ "\<lambda>F. F $ 0", OF this] 
    show "c = 0 \<and> c' = 1" by simp_all
qed

lemma E_neq_0 [simp]: "\<not>E (c :: 'a :: field_char_0) = 0"
  unfolding fps_const_0_eq_0 [symmetric] E_eq_fps_const_iff by simp  

lemma E_eq_1_iff [simp]: "E (c :: 'a :: field_char_0) = 1 \<longleftrightarrow> c = 0"
  unfolding fps_const_1_eq_1 [symmetric] E_eq_fps_const_iff by simp
    
lemma E_neq_numeral_iff [simp]: "E (c :: 'a :: field_char_0) = numeral n \<longleftrightarrow> c = 0 \<and> n = Num.One"
  unfolding numeral_fps_const E_eq_fps_const_iff by simp
  
lemma numeral_neq_fps_zero [simp]: "(numeral f :: 'a :: field_char_0 fps) \<noteq> 0"
proof
  assume "numeral f = (0 :: 'a fps)"
  from arg_cong[of _ _ "\<lambda>F. F $ 0", OF this] show False by simp
qed 

lemma fps_deriv_of_nat [simp]: "fps_deriv (of_nat n) = 0"
  by (simp add: fps_of_nat [symmetric])
lemma fps_deriv_of_int [simp]: "fps_deriv (of_int n) = 0"
  by (simp add: fps_of_int [symmetric])
lemma fps_deriv_numeral [simp]: "fps_deriv (numeral n) = 0"
  by (simp add: numeral_fps_const)
    
lemma fps_0th_higher_deriv: 
  "(fps_deriv ^^ n) f $ 0 = (fact n * f $ n :: 'a :: {comm_ring_1, semiring_char_0})"
  by (induction n arbitrary: f) (simp_all del: funpow.simps add: funpow_Suc_right algebra_simps)
(* END TODO *)


text \<open>
  The following operator is a variant of the @{term XD} operator where the multiplication
  is not with @{term X}, but with an arbitrary formal power series. It is not quite clear 
  if this operator has a less ad-hoc meaning than the fashion in which we use it; it is, 
  however, very useful for proving the relationship between Stirling numbers and Bernoulli
  numbers.
\<close>

definition XD' where "XD' a = (\<lambda>b. a * fps_deriv b)"    

lemma XD'_0 [simp]: "XD' a 0 = 0" by (simp add: XD'_def)
lemma XD'_1 [simp]: "XD' a 1 = 0" by (simp add: XD'_def)
lemma XD'_fps_const [simp]: "XD' a (fps_const b) = 0" by (simp add: XD'_def)
lemma XD'_fps_of_nat [simp]: "XD' a (of_nat b) = 0" by (simp add: XD'_def)
lemma XD'_fps_of_int [simp]: "XD' a (of_int b) = 0" by (simp add: XD'_def)
lemma XD'_fps_numeral [simp]: "XD' a (numeral b) = 0" by (simp add: XD'_def)
  
lemma XD'_add [simp]: "XD' a (b + c :: 'a :: comm_ring_1 fps) = XD' a b + XD' a c"
  by (simp add: XD'_def algebra_simps)
    
lemma XD'_minus [simp]: "XD' a (b - c :: 'a :: comm_ring_1 fps) = XD' a b - XD' a c"
  by (simp add: XD'_def algebra_simps)
    
lemma XD'_prod: "XD' a (b * c :: 'a :: comm_ring_1 fps) = XD' a b * c + b * XD' a c"
  by (simp add: XD'_def algebra_simps)
    
lemma XD'_power: "XD' a (b ^ n :: 'a :: idom fps) = of_nat n * b ^ (n - 1) * XD' a b"
proof (cases "n = 0")
  case False
  have "b * XD' a (b ^ n) = of_nat n * b ^ n * XD' a b"
    by (induction n) (simp_all add: XD'_prod algebra_simps)
  also have "\<dots> = b * (of_nat n * b ^ (n - 1) * XD' a b)" 
    by (cases n) (simp_all add: algebra_simps)
  finally show ?thesis using False 
    by (subst (asm) mult_cancel_left) (auto simp: power_0_left)
qed simp_all
  
lemma XD'_power_Suc: "XD' a (b ^ Suc n :: 'a :: idom fps) = of_nat (Suc n) * b ^ n * XD' a b"
  by (subst XD'_power) simp_all
  
lemma XD'_sum: "XD' a (sum f A) = sum (\<lambda>x. XD' (a :: 'a :: comm_ring_1 fps) (f x)) A"
  by (induction A rule: infinite_finite_induct) simp_all

lemma XD'_funpow_affine:
  fixes G H :: "real fps"
  assumes [simp]: "fps_deriv G = 1"
  defines "S \<equiv> \<lambda>n i. fps_const (real (Stirling n i))"
  shows "(XD' G ^^ n) H = 
           (\<Sum>m\<le>n. S n m * G ^ m * (fps_deriv ^^ m) H)"
proof (induction n arbitrary: H)
  case 0
  thus ?case by (simp add: S_def)
next
  case (Suc n H)
  have "(\<Sum>m\<le>Suc n. S (Suc n) m * G ^ m * (fps_deriv ^^ m) H) = 
        (\<Sum>i\<le>n. of_nat (Suc i) * S n (Suc i) *  G ^ Suc i * (fps_deriv ^^ Suc i) H) +
        (\<Sum>i\<le>n. S n i * G ^ Suc i * (fps_deriv ^^ Suc i) H)" 
    (is "_ = sum (\<lambda>i. ?f (Suc i)) \<dots> + ?S2")
    by (subst sum_atMost_Suc_shift) (simp_all add: sum.distrib algebra_simps fps_of_nat S_def
          fps_const_add [symmetric] fps_const_mult [symmetric] del: fps_const_add fps_const_mult)
  also have "sum (\<lambda>i. ?f (Suc i)) {..n} = sum (\<lambda>i. ?f (Suc i)) {..<n}"
    by (intro sum.mono_neutral_right) (auto simp: S_def)
  also have "\<dots> = ?f 0 + \<dots>" by simp
  also have "\<dots> = sum ?f {..n}" by (subst sum_atMost_shift [symmetric]) simp_all
  also have "\<dots> + ?S2 = (\<Sum>x\<le>n. XD' G (S n x * G ^ x * (fps_deriv ^^ x) H))"
    unfolding sum.distrib [symmetric]
  proof (rule sum.cong, goal_cases)
    case (2 i)
    thus ?case unfolding XD'_prod XD'_power
      by (cases i) (auto simp: XD'_prod XD'_power_Suc algebra_simps of_nat_diff S_def XD'_def)
  qed simp_all
  also have "\<dots> = (XD' G ^^ Suc n) H" by (simp add: Suc.IH XD'_sum)
  finally show ?case ..
qed


subsection \<open>Generating function of Stirling numbers\<close>

lemma Stirling_n_0: "Stirling n 0 = (if n = 0 then 1 else 0)"
  by (cases n) simp_all

text \<open>
  The generating function of Stirling numbers w.\,r.\,t.\ their first argument:
    \[\sum_{n=0}^\infty \genfrac{\{}{\}}{0pt}{}{n}{m} \frac{x^n}{n!} = \frac{(e^x - 1)^m}{m!}\]
\<close>
definition Stirling_fps :: "nat \<Rightarrow> real fps" where
  "Stirling_fps m = fps_const (1 / fact m) * (E 1 - 1) ^ m"
  
theorem sum_Stirling_binomial:
  "Stirling (Suc n) (Suc m) = (\<Sum>i = 0..n. Stirling i m * (n choose i))"
proof -
  have "real (Stirling (Suc n) (Suc m)) = real (\<Sum>i = 0..n. Stirling i m * (n choose i))"
  proof (induction n arbitrary: m)
    case (Suc n m)
    have "real (\<Sum>i = 0..Suc n. Stirling i m * (Suc n choose i)) = 
            real (\<Sum>i = 0..n. Stirling (Suc i) m * (Suc n choose Suc i)) + real (Stirling 0 m)"
      by (subst sum.atLeast0_atMost_Suc_shift) simp_all
    also have "real (\<Sum>i = 0..n. Stirling (Suc i) m * (Suc n choose Suc i)) = 
                 real (\<Sum>i = 0..n. (n choose i) * Stirling (Suc i) m) +
                 real (\<Sum>i = 0..n. (n choose Suc i) * Stirling (Suc i) m)"
      by (simp add: algebra_simps sum.distrib)
    also have "(\<Sum>i = 0..n. (n choose Suc i) * Stirling (Suc i) m) =
                 (\<Sum>i = Suc 0..Suc n. (n choose i) * Stirling i m)"
      by (subst sum_shift_bounds_cl_Suc_ivl) simp_all
    also have "\<dots> = (\<Sum>i = Suc 0..n. (n choose i) * Stirling i m)"
      by (intro sum.mono_neutral_right) auto
    also have "\<dots> = real (\<Sum>i = 0..n.  Stirling i m * (n choose i)) - real (Stirling 0 m)"
      by (simp add: sum_head_Suc mult_ac)
    also have "real (\<Sum>i = 0..n. Stirling i m * (n choose i)) = real (Stirling (Suc n) (Suc m))"
      by (rule Suc.IH [symmetric])
    also have "real (\<Sum>i = 0..n. (n choose i) * Stirling (Suc i) m) = 
                 real m * real (Stirling (Suc n) (Suc m)) + real (Stirling (Suc n) m)"
      by (cases m; (simp only: Suc.IH, simp add: algebra_simps sum.distrib 
                      sum_distrib_left sum_distrib_right))
    also have "\<dots> + (real (Stirling (Suc n) (Suc m)) - real (Stirling 0 m)) + real (Stirling 0 m) =
                 real (Suc m * Stirling (Suc n) (Suc m) + Stirling (Suc n) m)"
      by (simp add: algebra_simps del: Stirling.simps)
    also have "Suc m * Stirling (Suc n) (Suc m) + Stirling (Suc n) m = 
                 Stirling (Suc (Suc n)) (Suc m)"
      by (rule Stirling.simps(4) [symmetric])
    finally show ?case ..
  qed simp_all
  thus ?thesis by (subst (asm) of_nat_eq_iff)
qed

lemma Stirling_fps_aux: "(E 1 - 1) ^ m $ n * fact n = fact m * real (Stirling n m)"
proof (induction m arbitrary: n)
  case 0
  thus ?case by (simp add: Stirling_n_0)
next
  case (Suc m n)
  show ?case
  proof (cases n)
    case 0
    thus ?thesis by simp
  next
    case (Suc n')
    hence "(E 1 - 1 :: real fps) ^ Suc m $ n * fact n = 
              fps_deriv ((E 1 - 1) ^ Suc m) $ n' * fact n'"
      by (simp_all add: algebra_simps del: power_Suc)
    also have "fps_deriv ((E 1 - 1 :: real fps) ^ Suc m) = 
                 fps_const (real (Suc m)) * ((E 1 - 1) ^ m * E 1)"
      by (subst fps_deriv_power) simp_all
    also have "\<dots> $ n' * fact n' = 
      real (Suc m) * ((\<Sum>i = 0..n'. (E 1 - 1) ^ m $ i / fact (n' - i)) * fact n')"
      unfolding fps_mult_left_const_nth
      by (simp add: fps_mult_nth Suc.IH sum_distrib_right del: of_nat_Suc)
    also have "(\<Sum>i = 0..n'. (E 1 - 1 :: real fps) ^ m $ i / fact (n' - i)) * fact n' = 
                 (\<Sum>i = 0..n'. (E 1 - 1) ^ m $ i * fact n' / fact (n' - i))"
      by (subst sum_distrib_right, rule sum.cong) (simp_all add: divide_simps)
    also have "\<dots> = (\<Sum>i = 0..n'. (E 1 - 1) ^ m $ i * fact i * (n' choose i))"
      by (intro sum.cong refl) (simp_all add: binomial_fact)
    also have "\<dots> = (\<Sum>i = 0..n'. fact m * real (Stirling i m) * real (n' choose i))" 
      by (simp only: Suc.IH)
    also have "real (Suc m) * \<dots> = fact (Suc m) * 
                 (\<Sum>i = 0..n'. real (Stirling i m) * real (n' choose i))" (is "_ = _ * ?S")
      by (simp add: sum_distrib_left sum_distrib_right mult_ac del: of_nat_Suc)
    also have "?S = Stirling (Suc n') (Suc m)"
      by (subst sum_Stirling_binomial) simp
    also have "Suc n' = n" by (simp add: Suc)
    finally show ?thesis .
  qed
qed

lemma Stirling_fps_nth: "Stirling_fps m $ n = Stirling n m / fact n"
  unfolding Stirling_fps_def using Stirling_fps_aux[of m n] by (simp add: field_simps)
    
theorem Stirling_fps_altdef: "Stirling_fps m = Abs_fps (\<lambda>n. Stirling n m / fact n)"
  by (simp add: fps_eq_iff Stirling_fps_nth)

theorem Stirling_closed_form:
  "real (Stirling n k) = (\<Sum>j\<le>k. (-1)^(k - j) * real (k choose j) * real j ^ n) / fact k"
proof -
  have "(E 1 - 1 :: real fps) = (E 1 + (-1))" by simp
  also have "\<dots> ^ k = (\<Sum>j = 0..k. of_nat (k choose j) * E 1 ^ j * (- 1) ^ (k - j))" 
    unfolding binomial_ring ..
  also have "\<dots> = (\<Sum>j = 0..k. fps_const ((-1) ^ (k - j) * real (k choose j)) * E (real j))"
    by (simp add: fps_const_mult [symmetric] fps_const_power [symmetric] 
                  fps_const_neg [symmetric] mult_ac fps_of_nat E_power_mult
             del: fps_const_mult fps_const_power fps_const_neg)
  also have "\<dots> $ n = (\<Sum>j = 0..k. (- 1) ^ (k - j) * real (k choose j) * real j ^ n) / fact n" 
    by (simp add: fps_sum_nth sum_divide_distrib)
  also have "\<dots> * fact n = (\<Sum>j = 0..k. (- 1) ^ (k - j) * real (k choose j) * real j ^ n)"
    by simp
  also note Stirling_fps_aux[of k n]
  finally show ?thesis by (simp add: atLeast0AtMost field_simps)
qed


subsection \<open>Generating function of Bernoulli numbers\<close>

text \<open>
  We will show that the Bernoulli numbers are the coefficients of the
  exponential generating function $\frac{x}{e^x - 1}$, i.\,e.
    \[\sum_{n=0}^\infty B_n \frac{x^n}{n!} = \frac{x}{e^x - 1}\]
\<close> 
definition bernoulli_fps :: "real fps" where "bernoulli_fps = X / (E 1 - 1)"

lemma bernoulli_fps_altdef: "bernoulli_fps = Abs_fps (\<lambda>n. bernoulli n / fact n)"
  and bernoulli_fps_aux:    "bernoulli_fps * (E 1 - 1) = X"
proof -
  have *: "Abs_fps (\<lambda>n. bernoulli n / fact n) * (E 1 - 1) = X"  
  proof (rule fps_ext)
    fix n
    have "(Abs_fps (\<lambda>n. bernoulli n / fact n) * (E 1 - 1)) $ n = 
            (\<Sum>i = 0..n. bernoulli i * (1 / fact (n - i) - (if n = i then 1 else 0)) / fact i)"
      by (simp add: fps_mult_nth split: if_splits)
    also have "\<dots> = (\<Sum>i = 0..n. bernoulli i / (fact i * fact (n - i)) -
                                    (if n = i then bernoulli i / fact i else 0))"
      by (intro sum.cong) (simp_all add: field_simps)
    also have "\<dots> = (\<Sum>i = 0..n. bernoulli i / (fact i * fact (n - i))) - bernoulli n / fact n" 
      unfolding sum_subtractf by (subst sum.delta') simp_all
    also have "\<dots> = (\<Sum>i<n. bernoulli i / (fact i * fact (n - i)))"
      by (cases n) (simp_all add: atLeast0AtMost lessThan_Suc_atMost [symmetric])
    also have "\<dots> = (\<Sum>i<n. fact n * (bernoulli i / (fact i * fact (n - i)))) / fact n"
      by (subst sum_distrib_left [symmetric]) simp_all
    also have "(\<Sum>i<n. fact n * (bernoulli i / (fact i * fact (n - i)))) =
                 (\<Sum>i<n. (n choose i) * bernoulli i)" 
      by (intro sum.cong) (simp_all add: binomial_fact)
    also have "\<dots> / fact n = X $ n" by (subst sum_binomial_times_bernoulli') simp_all
    finally show "(Abs_fps (\<lambda>n. bernoulli n / fact n) * (E 1 - 1)) $ n = X $ n" .
  qed
  moreover show "bernoulli_fps = Abs_fps (\<lambda>n. bernoulli n / fact n)"
    unfolding bernoulli_fps_def by (subst * [symmetric]) simp_all
  ultimately show "bernoulli_fps * (E 1 - 1) = X" by simp
qed
    
theorem fps_nth_bernoulli_fps [simp]: "fps_nth bernoulli_fps n = bernoulli n / fact n"
  by (simp add: bernoulli_fps_altdef)
  
theorem bernoulli_odd_eq_0:
  assumes "n \<noteq> 1" and "odd n"
  shows   "bernoulli n = 0"
proof -
  from bernoulli_fps_aux have "2 * bernoulli_fps * (E 1 - 1) = 2 * X" by simp
  hence "(2 * bernoulli_fps + X) * (E 1 - 1) = X * (E 1 + 1)" 
    by (simp add: algebra_simps)
  also have "E 1 - 1 = E(1/2) * (E (1/2) - E (-1/2 :: real))" 
    by (simp add: algebra_simps E_add_mult [symmetric])
  also have "E 1 + 1 = E(1/2) * (E (1/2) + E (-1/2 :: real))" 
    by (simp add: algebra_simps E_add_mult [symmetric])
  finally have "E (1/2) * ((2 * bernoulli_fps + X) * (E (1/2) - E (- 1/2))) =
                   E (1/2) * (X * (E (1/2) + E (-1/2)))" by (simp add: algebra_simps)
  hence *: "(2 * bernoulli_fps + X) * (E (1/2) - E (- 1/2)) = X * (E (1/2) + E (-1/2))" 
    (is "?lhs = ?rhs") by (subst (asm) mult_cancel_left) simp_all
  have "fps_compose ?lhs (-X) = fps_compose ?rhs (-X)" by (simp only: *)
  also have "fps_compose ?lhs (-X) = 
               (-2 * (bernoulli_fps oo - X) + X) * (E ((1/2)) - E (-1/2))" 
    by (simp add: fps_compose_mult_distrib fps_compose_add_distrib
                   fps_compose_sub_distrib algebra_simps)
  also have "fps_compose ?rhs (-X) = -?rhs"
    by (simp add: fps_compose_mult_distrib fps_compose_add_distrib fps_compose_sub_distrib)
  also note * [symmetric]
  also have "- ((2 * bernoulli_fps + X) * (E (1/2) - E (-1/2))) = 
               ((-2 * bernoulli_fps - X) * (E (1/2) - E (-1/2)))" by (simp add: algebra_simps)
  finally have "2 * (bernoulli_fps oo - X) = 2 * (bernoulli_fps + X)"
    by (subst (asm) mult_cancel_right) (simp add: algebra_simps)
  hence **: "bernoulli_fps oo -X = bernoulli_fps + X" by (subst (asm) mult_cancel_left) simp
  
  from assms have "(bernoulli_fps oo -X) $ n = bernoulli n / fact n"
    by (subst **) simp
  also have "-X = fps_const (-1 :: real) * X" 
    by (simp only: fps_const_neg [symmetric] fps_const_1_eq_1) simp
  also from assms have "(bernoulli_fps oo \<dots>) $ n = - bernoulli n / fact n"
    by (subst fps_compose_linear) simp
  finally show ?thesis by simp
qed
  
text \<open>
  The following simplification rule takes care of rewriting @{term "bernoulli n"} to $0$ for
  any odd numeric constant greater than $1$:
\<close>
lemma bernoulli_odd_numeral_eq_0 [simp]: "bernoulli (numeral (Num.Bit1 n)) = 0"
  by (rule bernoulli_odd_eq_0[OF _ odd_numeral]) auto
  
text \<open>
  The following explicit formula for Bernoulli numbers can also derived reasonably easily
  using the generating functions of Stirling numbers and Bernoulli numbers. The proof follows 
  an answer by Marko Riedel on the Mathematics StackExchange~\cite{riedel_mathse_2014}.
\<close>
theorem bernoulli_altdef: 
  "bernoulli n = (\<Sum>m\<le>n. \<Sum>k\<le>m. (-1)^k * real (m choose k) * real k^n / real (Suc m))"
proof -
  have "(\<Sum>m\<le>n. \<Sum>k\<le>m. (-1)^k * real (m choose k) * real k^n / real (Suc m)) =
          (\<Sum>m\<le>n. (\<Sum>k\<le>m. (-1)^k * real (m choose k) * real k^n) / real (Suc m))"
    by (subst sum_divide_distrib) simp_all
  also have "\<dots> = fact n * (\<Sum>m\<le>n. (- 1) ^ m  / real (Suc m) * (E 1 - 1) ^ m $ n)"
  proof (subst sum_distrib_left, intro sum.cong refl)
    fix m assume m: "m \<in> {..n}"
    have "(\<Sum>k\<le>m. (-1)^k * real (m choose k) * real k^n) = 
            (-1)^m * (\<Sum>k\<le>m. (-1)^(m - k) * real (m choose k) * real k^n)"
      by (subst sum_distrib_left, intro sum.cong refl) (auto simp: minus_one_power_iff)
    also have "\<dots> = (-1) ^ m * (real (Stirling n m) * fact m)" 
      by (subst Stirling_closed_form) simp_all
    also have "real (Stirling n m) = Stirling_fps m $ n * fact n"
      by (subst Stirling_fps_nth) simp_all
    also have "\<dots> * fact m = (E 1 - 1) ^ m $ n * fact n" by (simp add: Stirling_fps_def)
    finally show "(\<Sum>k\<le>m. (-1)^k * real (m choose k) * real k^n) / real (Suc m) = 
                     fact n * ((- 1) ^ m / real (Suc m) * (E 1 - 1) ^ m $ n)" by simp
  qed
  also have "(\<Sum>m\<le>n. (- 1) ^ m / real (Suc m) * (E 1 - 1) ^ m $ n) =
                fps_compose (Abs_fps (\<lambda>m. (-1) ^ m / real (Suc m))) (E 1 - 1) $ n"
    by (simp add: fps_compose_def atLeast0AtMost fps_sum_nth)
  also have "L 1 = X * Abs_fps (\<lambda>m. (-1) ^ m / real (Suc m))"
    unfolding L_def by (auto simp: fps_eq_iff)
  hence "Abs_fps (\<lambda>m. (-1) ^ m / real (Suc m)) = L 1 / X" by simp
  also have "fps_compose \<dots> (E 1 - 1) = fps_compose (L 1) (E 1 - 1) / (E 1 - 1)"
    by (simp add: fps_compose_divide_distrib)
  also have "fps_compose (L 1) (E 1 - 1 :: real fps) = X" by (simp add: L_E_inv LE_compose)
  also have "(X / (E 1 - 1)) = bernoulli_fps" by (simp add: bernoulli_fps_def)
  also have "fact n * \<dots> $ n = bernoulli n" by simp
  finally show ?thesis ..
qed


subsection \<open>Akiyama--Tanigawa algorithm\<close>
  
text \<open>
  First, we define the Akiyama--Tanigawa number triangle as shown by Kaneko~\cite{kaneko2000}.
  We define this generically, parametrised by the first row. This makes the proofs a 
  little bit more modular.
\<close>

fun gen_akiyama_tanigawa :: "(nat \<Rightarrow> real) \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> real" where
  "gen_akiyama_tanigawa f 0 m = f m"
| "gen_akiyama_tanigawa f (Suc n) m = 
     real (Suc m) * (gen_akiyama_tanigawa f n m - gen_akiyama_tanigawa f n (Suc m))"
  
lemma gen_akiyama_tanigawa_0 [simp]: "gen_akiyama_tanigawa f 0 = f"
  by (simp add: fun_eq_iff)

text \<open>
  The ``regular'' Akiyama--Tanigawa triangle is the one that is used for reading off
  Bernoulli numbers:
\<close>

definition akiyama_tanigawa where
  "akiyama_tanigawa = gen_akiyama_tanigawa (\<lambda>n. 1 / real (Suc n))"

context
begin

private definition AT_fps :: "(nat \<Rightarrow> real) \<Rightarrow> nat \<Rightarrow> real fps" where
  "AT_fps f n = (X - 1) * Abs_fps (gen_akiyama_tanigawa f n)"

private lemma AT_fps_Suc: "AT_fps f (Suc n) = (X - 1) * fps_deriv (AT_fps f n)"
proof (rule fps_ext)
  fix m :: nat
  show "AT_fps f (Suc n) $ m = ((X - 1) * fps_deriv (AT_fps f n)) $ m"
    by (cases m) (simp_all add: AT_fps_def fps_deriv_def algebra_simps)
qed
  
private lemma AT_fps_altdef:
  "AT_fps f n = 
     (\<Sum>m\<le>n. fps_const (real (Stirling n m)) * (X - 1)^m * (fps_deriv ^^ m) (AT_fps f 0))"
proof -
  have "AT_fps f n = (XD' (X - 1) ^^ n) (AT_fps f 0)"
    by (induction n) (simp_all add: AT_fps_Suc XD'_def)
  also have "\<dots> = (\<Sum>m\<le>n. fps_const (real (Stirling n m)) * (X - 1) ^ m * 
                             (fps_deriv ^^ m) (AT_fps f 0))"
    by (rule XD'_funpow_affine) simp_all
  finally show ?thesis .
qed

private lemma AT_fps_0_nth: "AT_fps f 0 $ n = (if n = 0 then -f 0 else f (n - 1) - f n)"
  by (simp add: AT_fps_def algebra_simps)


text \<open>
  The following fact corresponds to Proposition 1 in Kaneko's proof:
\<close>
lemma gen_akiyama_tanigawa_n_0: 
  "gen_akiyama_tanigawa f n 0 = 
     (\<Sum>k\<le>n. (- 1) ^ k * fact k * real (Stirling (Suc n) (Suc k)) * f k)"
proof (cases "n = 0")
  case False
  note [simp del] = gen_akiyama_tanigawa.simps
  have "gen_akiyama_tanigawa f n 0 = -(AT_fps f n $ 0)" by (simp add: AT_fps_def)
  also have "AT_fps f n $ 0 = (\<Sum>k\<le>n. real (Stirling n k) * (- 1) ^ k * (fact k * AT_fps f 0 $ k))"
    by (subst AT_fps_altdef) (simp add: fps_sum_nth fps_nth_power_0 fps_0th_higher_deriv)
  also have "\<dots> = (\<Sum>k\<le>n. real (Stirling n k) * (- 1) ^ k * (fact k * (f (k - 1) - f k)))"
    using False by (intro sum.cong refl) (auto simp: Stirling_n_0 AT_fps_0_nth)
  also have "\<dots> = (\<Sum>k\<le>n. fact k * (real (Stirling n k) * (- 1) ^ k) * f (k - 1)) -
                    (\<Sum>k\<le>n. fact k * (real (Stirling n k) * (- 1) ^ k) * f k)"
     (is "_ = sum ?f _ - ?S2") by (simp add: sum_subtractf algebra_simps)
  also from False have "sum ?f {..n} = sum ?f {0<..n}"
    by (intro sum.mono_neutral_right) (auto simp: Stirling_n_0)
  also have "\<dots> = sum ?f {0<..Suc n}"
    by (intro sum.mono_neutral_left) auto
  also have "{0<..Suc n} = {Suc 0..Suc n}" by auto
  also have "sum ?f \<dots> = sum (\<lambda>n. ?f (Suc n)) {0..n}"
    by (subst sum.atLeast_Suc_atMost_Suc_shift) simp_all
  also have "{0..n} = {..n}" by auto
  also have "sum (\<lambda>n. ?f (Suc n)) \<dots> - ?S2 = 
               (\<Sum>k\<le>n. -((-1)^k * fact k * real (Stirling (Suc n) (Suc k)) * f k))"
    by (subst sum_subtractf [symmetric], intro sum.cong) (simp_all add: algebra_simps)
  also have "-\<dots> = (\<Sum>k\<le>n. ((-1)^k * fact k * real (Stirling (Suc n) (Suc k)) * f k))"
    by (simp add: sum_negf)
  finally show ?thesis .
qed simp_all

  
text \<open>
  The following lemma states that for $A(x) := \sum_{k=0}^\infty a_{0,k} x^k$, we have
    \[\sum_{n=0}^\infty a_{n,0}\frac{x^n}{n!} = e^x A(1 - e^x)\]
  which correspond's to Kaneko's remark at the end of Section 2. This seems to be easier 
  to formalise than his actual proof of his Theorem 1, since his proof contains 
  an infinite sum of formal power series, and it was unclear to us how to capture this
  formally.
\<close>
lemma gen_akiyama_tanigawa_fps: 
  "Abs_fps (\<lambda>n. gen_akiyama_tanigawa f n 0 / fact n) = E 1 * fps_compose (Abs_fps f) (1 - E 1)"
proof (rule fps_ext)
  fix n :: nat     
  have "(fps_const (fact n) * 
          (fps_compose (Abs_fps (\<lambda>n. gen_akiyama_tanigawa f 0 n)) (1 - E 1) * E 1)) $ n = 
          (\<Sum>m\<le>n. \<Sum>k\<le>m. (1 - E 1) ^ k $ m * fact n / fact (n - m) * f k)"
    unfolding fps_mult_left_const_nth
    by (simp add: fps_times_def fps_compose_def gen_akiyama_tanigawa_n_0 sum_Stirling_binomial
                  field_simps sum_distrib_left sum_distrib_right atLeast0AtMost
             del: Stirling.simps of_nat_Suc) 
  also have "\<dots> = (\<Sum>m\<le>n. \<Sum>k\<le>m. (-1)^k * fact k * real (Stirling m k) * real (n choose m) * f k)"
  proof (intro sum.cong refl, goal_cases)
    case (1 m k)
    have "(1 - E 1 :: real fps) ^ k = (-E 1 + 1 :: real fps) ^ k" by simp
    also have "\<dots> = (\<Sum>i\<le>k. of_nat (k choose i) * (-1) ^ i * E (real i))" 
      by (subst binomial_ring) (simp add: atLeast0AtMost power_minus' E_power_mult mult.assoc)
    also have "\<dots> = (\<Sum>i\<le>k. fps_const (real (k choose i) * (-1) ^ i) * E (real i))"
      by (simp add: fps_const_mult [symmetric] fps_of_nat fps_const_power [symmetric] 
                    fps_const_neg [symmetric] del: fps_const_mult fps_const_power fps_const_neg)
    also have "\<dots> $ m = (\<Sum>i\<le>k. real (k choose i) * (- 1) ^ i * real i ^ m) / fact m" 
      (is "_ = ?S / _") by (simp add: fps_sum_nth sum_divide_distrib [symmetric])
    also have "?S = (-1) ^ k * (\<Sum>i\<le>k. (-1) ^ (k - i) * real (k choose i) * real i ^ m)"
      by (subst sum_distrib_left, intro sum.cong refl) (auto simp: minus_one_power_iff)
    also have "(\<Sum>i\<le>k. (-1) ^ (k - i) * real (k choose i) * real i ^ m) = 
                 real (Stirling m k) * fact k"
      by (subst Stirling_closed_form) (simp_all add: field_simps)
    finally have *: "(1 - E 1 :: real fps) ^ k $ m * fact n / fact (n - m) = 
                       (- 1) ^ k * fact k * real (Stirling m k) * real (n choose m)"
      using 1 by (simp add: binomial_fact del: of_nat_Suc)
    show ?case using 1 by (subst *) simp
  qed
  also have "\<dots> = (\<Sum>m\<le>n. \<Sum>k\<le>n. (- 1) ^ k * fact k * 
                      real (Stirling m k) * real (n choose m) * f k)"
    by (rule sum.cong[OF refl], rule sum.mono_neutral_left) auto
  also have "\<dots> = (\<Sum>k\<le>n. \<Sum>m\<le>n. (- 1) ^ k * fact k * 
                      real (Stirling m k) * real (n choose m) * f k)"
    by (rule sum.commute)
  also have "\<dots> = gen_akiyama_tanigawa f n 0"
    by (simp add: gen_akiyama_tanigawa_n_0 sum_Stirling_binomial sum_distrib_left sum_distrib_right
          mult.assoc atLeast0AtMost del: Stirling.simps)
  finally show "Abs_fps (\<lambda>n. gen_akiyama_tanigawa f n 0 / fact n) $ n =
                  (E 1 * (Abs_fps f oo 1 - E 1)) $ n"
    by (subst (asm) fps_mult_left_const_nth) (simp add: field_simps del: of_nat_Suc)
qed

text \<open>
  As Kaneko notes in his afore-mentioned remark, if we let $a_{0,k} = \frac{1}{k+1}$, we obtain
    \[A(z) = \sum_{k=0}^\infty \frac{x^k}{k+1} = -\frac{\ln (1 - x)}{x}\]
  and therefore
    \[\sum_{n=0}^\infty a_{n,0} \frac{x^n}{n!} = \frac{x e^x}{e^x - 1} = \frac{x}{e^x - 1} + x,\]
  which immediately gives us the connection to the Bernoulli numbers.
\<close>
theorem bernoulli_conv_akiyama_tanigawa:
  "bernoulli n = akiyama_tanigawa n 0 - (if n = 1 then 1 else 0)"
proof -  
  define f where "f = (\<lambda>n. 1 / real (Suc n))"
  note gen_akiyama_tanigawa_fps[of f]
  also {
    have "L 1 = X * Abs_fps (\<lambda>n. (-1)^n / real (Suc n))"
      by (intro fps_ext) (simp del: of_nat_Suc add: L_def)
    hence "L 1 / X = Abs_fps (\<lambda>n. (-1)^n / real (Suc n))" by simp
    also have "fps_compose \<dots> (-X) = Abs_fps f"
      by (simp add: fps_compose_uminus' fps_eq_iff f_def)
    finally have "Abs_fps f = fps_compose (L 1 / X) (-X)" ..
    also have "L 1 / X oo - X oo 1 - E (1::real) = L 1 / X oo E 1 - 1"
      by (subst fps_compose_assoc [symmetric])
         (simp_all add: fps_compose_uminus)
    also have "\<dots> = (L 1 oo E 1 - 1) / (E 1 - 1)"
      by (subst fps_compose_divide_distrib) auto
    also have "\<dots> = X / (E 1 - 1)" by (simp add: L_E_inv LE_compose)
    finally have "Abs_fps f oo 1 - E 1 = X / (E 1 - 1)" .
  }
  finally have "Abs_fps (\<lambda>n. gen_akiyama_tanigawa f n 0 / fact n) = (X / (E 1 - 1)) * E 1"
    by simp
  also {
    have "X * E 1 + (-X) * (E 1 - 1 :: real fps) = X"  by (simp add: algebra_simps)
    hence "(X * E 1 + (-X) * (E 1 - 1)) / (E 1 - 1) = bernoulli_fps" 
      by (simp only: bernoulli_fps_def)
    also have "(X * E 1 + (-X) * (E 1 - 1)) / (E 1 - 1) = X * E 1 / (E 1 - 1) - (X :: real fps)"
      by (subst div_mult_self1) simp_all
    also have "subdegree (E 1 - 1 :: real fps) \<le> 1" by (intro subdegree_leI) simp_all
    hence "(E 1 - 1 :: real fps) dvd X" by (subst fps_dvd_iff) simp_all
    hence "X * E 1 / (E 1 - 1) = X / (E 1 - 1 :: real fps) * E 1"
      by (subst dvd_div_mult) simp_all
    finally have "X / (E 1 - 1) * E 1 = bernoulli_fps + X" by (simp add: algebra_simps)
  }
  finally have "Abs_fps (\<lambda>n. gen_akiyama_tanigawa f n 0 / fact n) $ n = (bernoulli_fps + X) $ n"
    by (simp only: )
  thus ?thesis by (auto simp: field_simps akiyama_tanigawa_def f_def)
qed

end

  
subsection \<open>Efficient code\<close>
  
text \<open>
  We can now compute parts of the Akiyama--Tanigawa (and thereby Bernoulli numbers) 
  with reasonable efficiency but iterating the recurrence row by row. We essentially 
  start with some finite prefix of the zeroth row, say of length $n$, and then apply 
  the recurrence one to get a prefix of the first row of length $n - 1$ etc.
\<close>

fun akiyama_tanigawa_step_aux :: "nat \<Rightarrow> real list \<Rightarrow> real list" where
  "akiyama_tanigawa_step_aux m (x # y # xs) = 
     real m * (x - y) # akiyama_tanigawa_step_aux (Suc m) (y # xs)"
| "akiyama_tanigawa_step_aux m xs = []"

lemma length_akiyama_tanigawa_step_aux [simp]: 
  "length (akiyama_tanigawa_step_aux m xs) = length xs - 1"
  by (induction m xs rule: akiyama_tanigawa_step_aux.induct) simp_all

lemma nth_akiyama_tanigawa_step_aux: 
  "n < length xs - 1 \<Longrightarrow> 
     akiyama_tanigawa_step_aux m xs ! n = real (m + n) * (xs ! n - xs ! Suc n)"
proof (induction m xs arbitrary: n rule: akiyama_tanigawa_step_aux.induct)
  case (1 m x y xs n)
  thus ?case by (cases n) auto
qed auto

definition gen_akiyama_tanigawa_row where
  "gen_akiyama_tanigawa_row f n l = map (gen_akiyama_tanigawa f n) [0..<l]"
  
lemma length_gen_akiyama_tanigawa_row [simp]: "length (gen_akiyama_tanigawa_row f n l) = l"
  by (simp add: gen_akiyama_tanigawa_row_def)
    
lemma nth_gen_akiyama_tanigawa_row: 
  "i < l \<Longrightarrow> gen_akiyama_tanigawa_row f n l ! i = gen_akiyama_tanigawa f n i"
  by (simp add: gen_akiyama_tanigawa_row_def)
    
lemma gen_akiyama_tanigawa_row_0 [code]:
  "gen_akiyama_tanigawa_row f 0 l = map f [0..<l]"
  by (simp add: gen_akiyama_tanigawa_row_def)
    
lemma gen_akiyama_tanigawa_row_Suc [code]:
  "gen_akiyama_tanigawa_row f (Suc n) l = 
     akiyama_tanigawa_step_aux 1 (gen_akiyama_tanigawa_row f n (Suc l))"
  by (rule nth_equalityI) (auto simp: nth_gen_akiyama_tanigawa_row nth_akiyama_tanigawa_step_aux)

lemma gen_akiyama_tanigawa_row_numeral:
  "gen_akiyama_tanigawa_row f (numeral n) l = 
     akiyama_tanigawa_step_aux 1 (gen_akiyama_tanigawa_row f (pred_numeral n) (Suc l))"
  by (simp only: numeral_eq_Suc gen_akiyama_tanigawa_row_Suc)

lemma gen_akiyama_tanigawa_code [code]:
  "gen_akiyama_tanigawa f n k = last (gen_akiyama_tanigawa_row f n (Suc k))"
  by (subst last_conv_nth) (auto simp: nth_gen_akiyama_tanigawa_row length_0_conv [symmetric])

lemma bernoulli_code [code]:
  "bernoulli n = 
     (if n = 0 then 1 else if n = 1 then -1/2 else if odd n then 0 else akiyama_tanigawa n 0)"
proof (cases "n = 0 \<or> n = 1 \<or> odd n")
  case False
  thus ?thesis by (auto simp add: bernoulli_conv_akiyama_tanigawa)
qed (auto simp: bernoulli_odd_eq_0)

  
text \<open>
  Evaluation with the simplifier is much slower than by reflection, but can still be done 
  with much better efficiency than before:
\<close>
lemmas eval_bernoulli =
  akiyama_tanigawa_def gen_akiyama_tanigawa_code gen_akiyama_tanigawa_row_numeral
  numeral_2_eq_2 [symmetric] gen_akiyama_tanigawa_row_Suc upt_conv_Cons
  gen_akiyama_tanigawa_row_0 bernoulli_code[of "numeral n" for n]

(* This should only take a few seconds *)
lemma bernoulli_upto_20 [simp]:
  "bernoulli 2 = 1/6" "bernoulli 4 = - (1 / 30)" "bernoulli 6 * 42 = 1" "bernoulli 8 = - (1 / 30)"
  "bernoulli 10 * 66 = 5" "bernoulli 12 = - (691 / 2730)" "bernoulli 14 * 6 = 7"
  "bernoulli 16 = - (3617 / 510)" "bernoulli 18 * 798 = 43867" "bernoulli 20 = - (174611 / 330)"
  by (simp_all add: eval_bernoulli)

end