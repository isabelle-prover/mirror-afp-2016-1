section \<open>Spectral Radius Theory\<close>

text \<open>The following results show that the spectral radius characterize polynomial growth
  of matrix powers. However, for the polynomial bounds 
  they are restricted to upper-triangular matrices since only for those we have proven
  the existence of JNFs.\<close>

theory Spectral_Radius
imports
  Jordan_Normal_Form_Triangular
begin

definition "spectrum A = Collect (eigenvalue A)"

lemma spectrum_root_char_poly: assumes A: "(A :: 'a :: field mat) \<in> carrier\<^sub>m n n"
  shows "spectrum A = {k. poly (char_poly A) k = 0}"
  unfolding spectrum_def eigenvalue_root_char_poly[OF A, symmetric] by auto

lemma card_finite_spectrum: assumes A: "(A :: 'a :: field mat) \<in> carrier\<^sub>m n n"
  shows "finite (spectrum A)" "card (spectrum A) \<le> n"
proof -
  def CP \<equiv> "char_poly A"
  from spectrum_root_char_poly[OF A] have id: "spectrum A = { k. poly CP k = 0}"
    unfolding CP_def by auto
  from degree_monic_char_poly[OF A] have d: "degree CP = n" and c: "coeff CP n = 1"
    unfolding CP_def by auto
  from c have "CP \<noteq> 0" by auto
  from poly_roots_finite[OF this]
  show "finite (spectrum A)" unfolding id .
  from poly_roots_degree[OF `CP \<noteq> 0`]
  show "card (spectrum A) \<le> n" unfolding id using d by simp
qed

lemma spectrum_non_empty: assumes A: "(A :: complex mat) \<in> carrier\<^sub>m n n"
  and n: "n > 0"
  shows "spectrum A \<noteq> {}"
proof - 
  def CP \<equiv> "char_poly A"
  from spectrum_root_char_poly[OF A] have id: "spectrum A = { k. poly CP k = 0}"
    unfolding CP_def by auto
  from degree_monic_char_poly[OF A] have d: "degree CP > 0" using n
    unfolding CP_def by auto
  hence "\<not> constant (poly CP)" by (simp add: constant_degree)
  from fundamental_theorem_of_algebra[OF this] show ?thesis unfolding id by auto
qed

definition spectral_radius :: "complex mat \<Rightarrow> real" where 
  "spectral_radius A = Max (norm ` spectrum A)"

lemma spectral_radius_mem_max: assumes A: "A \<in> carrier\<^sub>m n n"
  and n: "n > 0"
  shows "spectral_radius A \<in> norm ` spectrum A" (is ?one)
  "a \<in> norm ` spectrum A \<Longrightarrow> a \<le> spectral_radius A"
proof -
  def SA \<equiv> "norm ` spectrum A"
  from card_finite_spectrum[OF A]
  have fin: "finite SA" unfolding SA_def by auto
  from spectrum_non_empty[OF A n] have ne: "SA \<noteq> {}" unfolding SA_def by auto
  note d = spectral_radius_def SA_def[symmetric] Sup_fin_Max[symmetric]
  show ?one unfolding d
    by (rule Sup_fin.closed[OF fin ne], auto simp: sup_real_def)
  assume "a \<in> norm ` spectrum A"
  thus "a \<le> spectral_radius A" unfolding d
    by (intro Sup_fin.coboundedI[OF fin])
qed

text \<open>If spectral radius is at most 1, and JNF exists, then we have polynomial growth.\<close>

lemma spectral_radius_jnf_norm_bound_le_1: assumes A: "A \<in> carrier\<^sub>m n n"
  and sr_1: "spectral_radius A \<le> 1"
  and jnf_exists: "\<exists> n_as. jordan_nf A n_as"
  shows "\<exists> c1 c2. \<forall> k. norm_bound (A ^\<^sub>m k) (c1 + c2 * of_nat k ^ (n - 1))"
proof -
  let ?p = "char_poly A"
  from char_poly_factorized[OF A] obtain as where cA: "char_poly A = (\<Prod>a\<leftarrow>as. [:- a, 1:])" 
    and len: "length as = n" by auto  
  show ?thesis
  proof (rule factored_char_poly_norm_bound[OF A cA jnf_exists])
    fix a
    show "length (filter (op = a) as) \<le> n" using len by auto
    assume "a \<in> set as"
    from linear_poly_root[OF this]
    have "poly ?p a = 0" unfolding cA by simp
    with spectrum_root_char_poly[OF A] 
    have mem: "norm a \<in> norm ` spectrum A" by auto
    with card_finite_spectrum[OF A] have "n > 0" by (cases n, auto)
    from spectral_radius_mem_max(2)[OF A this mem] sr_1 
    show "norm a \<le> 1" by auto
  qed
qed

text \<open>If spectral radius is smaller than 1, and JNF exists, then we have a constant bound.\<close>

lemma spectral_radius_jnf_norm_bound_less_1: assumes A: "A \<in> carrier\<^sub>m n n"
  and sr_1: "spectral_radius A < 1"
  and jnf_exists: "\<exists> n_as. jordan_nf A n_as" 
  shows "\<exists> c. \<forall> k. norm_bound (A ^\<^sub>m k) c"
proof -
  let ?p = "char_poly A"
  from char_poly_factorized[OF A] obtain as where cA: "char_poly A = (\<Prod>a\<leftarrow>as. [:- a, 1:])" by auto
  have "\<exists> c1 c2. \<forall> k. norm_bound (A ^\<^sub>m k) (c1 + c2 * of_nat k ^ (0 - 1))"
  proof (rule factored_char_poly_norm_bound[OF A cA jnf_exists])
    fix a
    assume "a \<in> set as"
    from linear_poly_root[OF this]
    have "poly ?p a = 0" unfolding cA by simp
    with spectrum_root_char_poly[OF A] 
    have mem: "norm a \<in> norm ` spectrum A" by auto
    with card_finite_spectrum[OF A] have "n > 0" by (cases n, auto)
    from spectral_radius_mem_max(2)[OF A this mem] sr_1 
    have lt: "norm a < 1" by auto
    thus "norm a \<le> 1" by auto
    from lt show "norm a = 1 \<Longrightarrow> length (filter (op = a) as) \<le> 0" by auto
  qed
  thus ?thesis by auto
qed

text \<open>If spectral radius is larger than 1, than we have exponential growth.\<close>

lemma spectral_radius_gt_1: assumes A: "A \<in> carrier\<^sub>m n n"
  and n: "n > 0"
  and sr_1: "spectral_radius A > 1"
  shows "\<exists> v c. v \<in> carrier\<^sub>v n \<and> norm c > 1 \<and> v \<noteq> \<zero>\<^sub>v n \<and> A ^\<^sub>m k \<otimes>\<^sub>m\<^sub>v v = c^k \<odot>\<^sub>v v"
proof -
  from sr_1 spectral_radius_mem_max[OF A n] obtain ev 
    where ev: "ev \<in> spectrum A" and gt: "norm ev > 1" by auto
  from ev[unfolded spectrum_def eigenvalue_def[abs_def]] 
    obtain v where ev: "eigenvector A v ev" by auto
  from eigenvector_pow[OF A this] this[unfolded eigenvector_def] A gt
  show ?thesis
    by (intro exI[of _ v], intro exI[of _ ev], auto)
qed


text \<open>If spectral radius is at most 1 for an upper_triangular matrix, then we have polynomial growth.\<close>

lemma spectral_radius_jnf_norm_bound_le_1_upper_triangular: assumes A: "A \<in> carrier\<^sub>m n n"
  and upper_t: "upper_triangular (A :: complex mat)"
  and sr_1: "spectral_radius A \<le> 1"
  shows "\<exists> c1 c2. \<forall> k. norm_bound (A ^\<^sub>m k) (c1 + c2 * of_nat k ^ (n - 1))"
  by (rule spectral_radius_jnf_norm_bound_le_1[OF A sr_1],
    insert triangular_to_jnf_vector[OF A upper_t], blast)

text \<open>If spectral radius is less than 1 for an upper_triangular matrix, then we have a constant bound.\<close>

lemma spectral_radius_jnf_norm_bound_less_1_upper_triangular: assumes A: "A \<in> carrier\<^sub>m n n"
  and upper_t: "upper_triangular (A :: complex mat)"
  and sr_1: "spectral_radius A < 1"
  shows "\<exists> c. \<forall> k. norm_bound (A ^\<^sub>m k) c"
  by (rule spectral_radius_jnf_norm_bound_less_1[OF A sr_1],
    insert triangular_to_jnf_vector[OF A upper_t], blast)

end