(* License: LGPL *)
(*
Author: Julian Parsert <julian.parsert@gmail.com>
Author: Cezary Kaliszyk
*)


section \<open> Pre Arrow-Debreu model \<close>

text \<open> Model similar to Arrow-Debreu model but with fewer assumptions,
       since we only need assumptions strong enough to proof the First Welfare Theorem. \<close>


theory Private_Ownership_Economy
  imports
    "~~/src/HOL/Analysis/Analysis"
    "Preferences"
    "Consumers"
    "Real_Vector_Spaces"
    "Preferences"
    "Utility_Functions"
    "Argmax"
    Exchange_Economy
begin

locale pre_arrow_debreu_model =
  fixes production_sets :: "'f \<Rightarrow> ('a::ordered_euclidean_space) set"
  fixes consumption_set :: "'a set"
  fixes agents :: "'i set"
  fixes firms :: "'f set"
  fixes \<E> :: "'i \<Rightarrow> 'a"  ("\<E>[_]")
  fixes Pref :: "'i \<Rightarrow> 'a relation" ("Pr[_]")
  fixes U :: "'i \<Rightarrow> 'a \<Rightarrow> real" ("U[_]")
  fixes Price :: "'a"
  fixes \<Theta> :: "'i \<Rightarrow> 'f \<Rightarrow> nat"  ("\<Theta>[_,_]")
  assumes cons_set_props: "pre_arrow_debreu_consumption_set consumption_set"
  assumes agent_props: "i \<in> agents \<Longrightarrow> eucl_ordinal_utility consumption_set (Pr[i]) (U[i])"
  assumes firms_comp_owned: "j \<in> firms \<Longrightarrow> (\<Sum>i\<in>agents. \<Theta>[i,j]) = 1"
  assumes price_cond: "Price > 0"
  assumes finite_nonepty_agents: "finite agents" and "agents \<noteq> {}"

sublocale pre_arrow_debreu_model \<subseteq> exchange_economy consumption_set agents \<E> Pref U Price
  by (metis exchange_economy.intro pre_arrow_debreu_model_axioms pre_arrow_debreu_model_def)

context pre_arrow_debreu_model
begin

text \<open> No restrictions on consumption set needed \<close>
lemma all_larger_zero_in_csset: "\<forall>x. x \<in> consumption_set"
  using cons_set_props pre_arrow_debreu_consumption_set_def by blast

text \<open> Calculate wealth of individual i in context of Private Ownership economy. \<close>

abbreviation poe_wealth
  where
    "poe_wealth i Y \<equiv> Price \<bullet> \<E>[i] + (\<Sum>j\<in>firms. \<Theta>[i,j] *\<^sub>R (Price \<bullet> Y j))"


subsection \<open> Feasiblity \<close>

definition feasible
  where
    "feasible X Y \<longleftrightarrow>
      (\<Sum>i\<in>agents. X i) \<le>
        (\<Sum>i\<in>agents. \<E>[i]) + (\<Sum>j\<in>firms. Y j) \<and>
      (\<forall>i \<in> agents. X i \<in> consumption_set) \<and>
      (\<forall>j \<in> firms. Y j \<in> production_sets j)"


subsection \<open> Profit maximisation \<close>

text \<open> In a production economy (which this is) we need to specify profit maximisation. \<close>

definition profit_maximisation
  where
    "profit_maximisation S = arg_max_set (\<lambda>x. Price \<bullet> x) S"


subsection \<open> Competitive Equilibirium \<close>

text \<open> Competitive equilibrium in context of production economy with private ownership.
             This includes the profit maximisation condition. \<close>

definition competitive_equilibrium
  where
    "competitive_equilibrium P X Y \<longleftrightarrow> feasible X Y \<and>
    (\<forall>j \<in> firms. (Y j) \<in> profit_maximisation (production_sets j)) \<and>
    (\<forall>i \<in> agents. (X i) \<in> arg_max_set U[i] (budget_constraint (poe_wealth i Y)))"

lemma competitive_equilibriumD [dest]:
  assumes "competitive_equilibrium P X Y"
  shows "feasible X Y \<and>
         (\<forall>j \<in> firms. (Y j) \<in> profit_maximisation (production_sets j)) \<and>
         (\<forall>i \<in> agents. (X i) \<in> arg_max_set U[i] (budget_constraint (poe_wealth i Y)))"
  using assms by (simp add: competitive_equilibrium_def)

lemma compet_max_profit:
  assumes "j \<in> firms"
  assumes "competitive_equilibrium P X Y"
  shows "Y j \<in> profit_maximisation (production_sets j)"
  using assms(1) assms(2) by blast

subsection \<open> Pareto Optimality \<close>

definition pareto_optimal
  where
    "pareto_optimal X Y \<longleftrightarrow>
              (feasible X Y \<and>
              (\<nexists>X' Y'. feasible X' Y' \<and> X' \<succ>Pareto X))"

lemma pareto_optimalI[intro]:
  assumes "feasible X Y"
    and "\<nexists>X' Y'. feasible X' Y' \<and> X' \<succ>Pareto X"
  shows "pareto_optimal X Y"
  using pareto_optimal_def assms(1) assms(2) by blast

lemma pareto_optimalD[dest]:
  assumes "pareto_optimal X Y"
  shows "feasible X Y" and "\<nexists>X' Y'. feasible X' Y' \<and> X' \<succ>Pareto X"
  using pareto_optimal_def assms by auto

lemma util_fun_def_holds: "i \<in> agents \<Longrightarrow> x \<succeq>[Pr[i]] y \<longleftrightarrow> U[i] x \<ge> U[i] y"
  by simp

lemma base_pref_is_ord_eucl_rpr: "i \<in> agents \<Longrightarrow> rational_preference consumption_set Pr[i]"
  by (simp add: base_pref_is_ord_eucl_rpr)

lemma prof_max_ge_all_in_pset:
  assumes "j \<in> firms"
  assumes "Y j \<in> profit_maximisation (production_sets j)"
  shows "\<forall>y \<in> production_sets j. Price \<bullet> Y j \<ge> Price \<bullet> y"
  using all_leq assms(2) profit_maximisation_def by fastforce


subsection \<open> Lemmas for final result \<close>

text \<open> Strictly preferred bundles are strictly more expensive. \<close>

lemma all_prefered_are_more_expensive:
  assumes i_agt: "i \<in> agents"
  assumes equil: "competitive_equilibrium Price \<X> \<Y>"
  assumes "z \<in> consumption_set"
  assumes "(U i) z > (U i) (\<X> i)"
  shows "z \<bullet> Price > Price \<bullet> (\<X> i)"
proof (rule ccontr)
  assume neg_as :  "\<not>(z \<bullet> Price > Price \<bullet> (\<X> i))"
  have xp_leq : "z \<bullet> Price \<le> Price \<bullet>  (\<X> i)"
    using \<open>\<not>z \<bullet> Price > Price \<bullet> (\<X> i)\<close> by auto
  have x_in_argmax: "(\<X> i) \<in> arg_max_set U[i] (budget_constraint (poe_wealth i \<Y>))"
    using equil i_agt by blast
  hence x_in: "\<X> i \<in> (budget_constraint (poe_wealth i \<Y>))"
    using argmax_sol_in_s [of "(\<X> i)" "U[i]" "budget_constraint (poe_wealth i \<Y>)"]
    by blast
  hence z_in_budget: "z \<in> (budget_constraint (poe_wealth i \<Y>))"
  proof -
    have z_leq_endow: "Price \<bullet> z \<le> Price \<bullet> (\<X> i)"
      by (metis xp_leq inner_commute)
    have z_in_cons: "z \<in> consumption_set"
      using assms by auto
    then show ?thesis
      using x_in budget_constraint_def z_leq_endow by auto
  qed
  have nex_prop: "\<nexists>e. e \<in>  (budget_constraint (poe_wealth i \<Y>)) \<and>
        U[i] e > U[i] (\<X> i)"
    using no_better_in_s[of "\<X> i" "U[i]"
        "budget_constraint (poe_wealth i \<Y>)"] x_in_argmax by blast
  have "z \<in> budget_constraint (poe_wealth i \<Y>) \<and> U[i] z > U[i] (\<X> i)"
    using assms z_in_budget by blast
  thus False using nex_prop
    by blast
qed

text \<open> Given local non-satiation, argmax will use the entire budget. \<close>

lemma am_utilises_entire_bgt:
  assumes i_agts: "i \<in> agents"
  assumes lns : "local_nonsatiation consumption_set Pr[i]"
  assumes argmax_sol : "X \<in> arg_max_set U[i] (budget_constraint (poe_wealth i Y))"
  shows "Price \<bullet> X = Price \<bullet> \<E>[i] + (\<Sum>j\<in>firms. \<Theta>[i,j] *\<^sub>R (Price \<bullet> Y j))"
proof -
  let ?wlt = "Price \<bullet> \<E>[i] + (\<Sum>j\<in>firms. \<Theta>[i,j] *\<^sub>R (Price \<bullet> Y j))"
  let ?bc = "budget_constraint (poe_wealth i Y)"
  have "X \<in> budget_constraint (poe_wealth i Y)"
    using argmax_sol_in_s [of "X" "U[i]" ?bc]
    using argmax_sol by blast
  hence is_leq: "X \<bullet> Price \<le> (poe_wealth i Y)"
    by (metis (mono_tags, lifting) budget_constraint_def
        inner_commute mem_Collect_eq)
  have not_less: "\<not>X \<bullet> Price < (poe_wealth i Y)"
  proof
    assume neg: "X \<bullet> Price < (poe_wealth i Y)"
    have bgt_leq: "\<forall>x\<in> ?bc. U[i] X \<ge> U[i] x"
      using leq_all_in_sol [of "X" "U[i]" "?bc"]
        all_leq [of "X" "U[i]" "?bc"]
        argmax_sol by blast
    define s_low where
      "s_low = {x . Price \<bullet> x < ?wlt}"
    have "\<exists>e > 0. ball X e \<subseteq> s_low"
    proof -
      have x_in_budget: "Price \<bullet> X < ?wlt"
        by (metis inner_commute neg)
      have s_low_open: "open s_low"
        using open_halfspace_lt s_low_def by blast
      then show ?thesis
        using s_low_open open_contains_ball_eq
          s_low_def x_in_budget by blast
    qed
    obtain e where
      "e > 0" and e: "ball X e \<subseteq> s_low"
      using \<open>\<exists>e>0. ball X e \<subseteq> s_low\<close> by blast
    obtain y where
      y_props: "y \<in> ball X e" "y \<succ>[Pref i] X"
      using \<open>0 < e\<close> consumption_set_member lns by blast
    have "y \<in> budget_constraint (poe_wealth i Y)"
    proof -
      have "y \<in> s_low"
        using \<open>y \<in> ball X e\<close> e by blast
      then show ?thesis
        by (simp add: s_low_def all_larger_zero_in_csset
            budget_constraint_def)
    qed
    then show False
      using bgt_leq i_agts y_props(2) by blast
  qed
  then show ?thesis
    by (metis inner_commute is_leq
        less_eq_real_def)
qed

corollary x_equil_x_ext_budget:
  assumes i_agt: "i \<in> agents"
  assumes lns : "local_nonsatiation consumption_set Pr[i]"
  assumes equilibrium : "competitive_equilibrium Price X Y"
  shows "Price \<bullet> X i = Price \<bullet> \<E>[i] + (\<Sum>j\<in>firms. \<Theta>[i,j] *\<^sub>R (Price \<bullet> Y j))"
proof -
  have "X i \<in> arg_max_set U[i] (budget_constraint (poe_wealth i Y))"
    using equilibrium i_agt by blast
  then show ?thesis
    using am_utilises_entire_bgt i_agt lns by blast
qed

lemma same_price_in_argmax :
  assumes i_agt: "i \<in> agents"
  assumes lns : "local_nonsatiation consumption_set Pr[i]"
  assumes "x \<in> arg_max_set (U[i]) (budget_constraint (poe_wealth i Y))"
  assumes "y \<in> arg_max_set (U[i]) (budget_constraint (poe_wealth i Y))"
  shows "(Price \<bullet> x) = (Price \<bullet> y)"
  using am_utilises_entire_bgt assms lns
  by (metis (no_types) am_utilises_entire_bgt assms(3) assms(4) i_agt lns)

text \<open> Greater or equal utility implies greater or equal value. \<close>

lemma utility_ge_price_ge :
  assumes agts: "i \<in> agents"
  assumes lns : "local_nonsatiation consumption_set Pr[i]"
  assumes equil: "competitive_equilibrium Price X Y"
  assumes geq: "U[i] z \<ge> U[i] (X i)"
    and "z \<in> consumption_set"
  shows "Price \<bullet> z \<ge> Price \<bullet> (X i)"
proof -
  let ?bc = "(budget_constraint (poe_wealth i Y))"
  have not_in : "z \<notin> arg_max_set (U[i]) ?bc \<Longrightarrow>
    Price \<bullet> z > (Price \<bullet> \<E>[i]) + (\<Sum>j\<in>(firms). (\<Theta>[i,j] *\<^sub>R (Price \<bullet> Y j)))"
  proof-
    assume "z \<notin> arg_max_set (U[i]) ?bc"
    moreover have "X i \<in> arg_max_set (U[i]) ?bc"
      using competitive_equilibriumD assms pareto_optimal_def
      by auto
    ultimately have "z \<notin> budget_constraint (poe_wealth i Y)"
      by (meson  geq leq_all_in_sol)
    then show ?thesis
      using budget_constraint_def assms by auto
  qed
  have x_in_argmax: "(X i) \<in> arg_max_set U[i] ?bc"
    using agts equil by blast
  hence x_in_budget: "(X i) \<in> ?bc"
    using argmax_sol_in_s [of "(X i)" "U[i]" "?bc"] by blast
  have "U[i] z = U[i] (X i) \<Longrightarrow> Price \<bullet> z \<ge> Price \<bullet> (X i)"
  proof(rule contrapos_pp)
    assume con_neg: "\<not> Price \<bullet> z \<ge> Price \<bullet> (X i)"
    then have "Price \<bullet> z < Price \<bullet> (X i)"
      by linarith
    then have z_in_argmax: "z \<in> arg_max_set U[i] ?bc"
    proof -
      have "Price \<bullet>(X i) = Price \<bullet> \<E>[i] + (\<Sum>j\<in>firms. \<Theta>[i,j] *\<^sub>R (Price \<bullet> Y j))"
        using agts am_utilises_entire_bgt lns x_in_argmax by blast
      then show ?thesis
        by (metis (no_types) con_neg less_eq_real_def not_in)
    qed
    have z_budget_utilisation: "Price \<bullet> z = Price \<bullet> (X i)"
      by (metis (no_types) agts am_utilises_entire_bgt lns x_in_argmax z_in_argmax)
    have "Price \<bullet> (X i) = Price \<bullet> \<E>[i] + (\<Sum>j\<in>firms. \<Theta>[i,j] *\<^sub>R (Price \<bullet> Y j))"
      using agts am_utilises_entire_bgt lns x_in_argmax by blast
    show "\<not> U[i] z = U[i] (X i)"
      using z_budget_utilisation con_neg by linarith
  qed
  thus ?thesis
    by (metis (no_types, hide_lams) agts all_prefered_are_more_expensive
        consumption_set_member equil eucl_less_le_not_le geq inner_commute neqE)
qed

lemma commutativity_sums_over_funs:
  fixes X :: "'x set"
  fixes Y :: "'y set"
  shows "(\<Sum>i\<in>X. \<Sum>j\<in>Y. (f i j *\<^sub>R C \<bullet> g j)) = (\<Sum>j\<in>Y.\<Sum>i\<in>X. (f i j *\<^sub>R C \<bullet> g j))"
  using Groups_Big.comm_monoid_add_class.sum.commute by auto

lemma assoc_fun_over_sum:
  fixes X :: "'x set"
  fixes Y :: "'y set"
  shows "(\<Sum>j\<in>Y. \<Sum>i\<in>X. f i j *\<^sub>R C \<bullet> g j) = (\<Sum>j\<in>Y. (\<Sum>i\<in>X. f i j) *\<^sub>R C \<bullet> g j)"
  by (simp add: inner_sum_left scaleR_left.sum)

text \<open> Walras' law in context of production economy with private ownership.
       That is, in an equilibrium demand equals supply. \<close>

lemma walras_law:
  assumes "\<And>i. i\<in>agents \<Longrightarrow> local_nonsatiation consumption_set Pr[i]"
  assumes "competitive_equilibrium Price X Y"
  shows "Price \<bullet> ((\<Sum>i\<in>agents. (X i)) - (\<Sum>i\<in>agents. \<E>[i]) - (\<Sum>j\<in>firms. Y j)) = 0"
proof -
  have value_equal: "Price \<bullet> (\<Sum>i\<in>agents. (X i)) = Price \<bullet> (\<Sum>i\<in>agents. \<E>[i]) + (\<Sum>i\<in>agents. \<Sum>f\<in>firms. \<Theta>[i,f] *\<^sub>R (Price \<bullet> Y f))"
  proof -
    have all_exhaust_bgt: "\<forall>i\<in>agents. Price \<bullet> (X i) = Price \<bullet> \<E>[i] + (\<Sum>j\<in>firms. \<Theta>[i,j] *\<^sub>R (Price \<bullet> (Y j)))"
      using assms x_equil_x_ext_budget by blast
    then show ?thesis
      by (simp add:all_exhaust_bgt inner_sum_right sum.distrib)
  qed
  have eq_1: "(\<Sum>i\<in>agents. \<Sum>j\<in>firms. (\<Theta>[i,j] *\<^sub>R Price \<bullet> Y j)) = (\<Sum>j\<in>firms. \<Sum>i\<in>agents. (\<Theta>[i,j] *\<^sub>R Price \<bullet> Y j))"
    using commutativity_sums_over_funs [of \<Theta> Price Y firms agents] by blast
  hence eq_2: "Price \<bullet> (\<Sum>i\<in>agents. X i) = Price \<bullet> (\<Sum>i\<in>agents. \<E>[i]) + (\<Sum>j\<in>firms. \<Sum>i\<in>agents. \<Theta>[i,j] *\<^sub>R Price \<bullet> Y j)"
    using value_equal by auto
  also  have eq_3: "...= Price \<bullet> (\<Sum>i\<in>agents. \<E>[i]) + (\<Sum>j\<in>firms. (\<Sum>i\<in>agents. \<Theta>[i,j]) *\<^sub>R Price \<bullet>  Y j)"
    using assoc_fun_over_sum[of "\<Theta>" Price Y agents firms] by auto
  also have eq_4: "... = Price \<bullet> (\<Sum>i\<in>agents. \<E>[i]) + (\<Sum>f\<in>firms. Price \<bullet>  Y f)"
    using firms_comp_owned by auto
  have comp_wise_inner: "Price \<bullet>  (\<Sum>i\<in>agents. X i) - (Price \<bullet> (\<Sum>i\<in>agents. \<E>[i])) - (\<Sum>f\<in>firms. Price \<bullet> Y f) = 0"
    using eq_1 eq_2 eq_3 eq_4 by linarith
  then show ?thesis
    by (metis (no_types) comp_wise_inner inner_diff_right inner_sum_right)
qed

subsection \<open> First Welfare Theorem \<close>

text \<open> Proof of First Welfare Theorem in context of production economy with private ownership. \<close>

theorem first_welfare_theorem_priv_own:
  assumes "\<And>i. i \<in> agents \<Longrightarrow> local_nonsatiation consumption_set Pr[i]"
  assumes "competitive_equilibrium Price \<X> \<Y>"
  shows "pareto_optimal \<X> \<Y>"
proof (rule ccontr)
  assume neg_as: "\<not> pareto_optimal \<X> \<Y>"
  have equili_feasible : "feasible \<X> \<Y>"
    using  assms by (simp add: competitive_equilibrium_def)
  obtain X' Y' where
    xprime_pareto: "feasible X' Y' \<and>
      (\<forall>i \<in> agents. U[i] (X' i) \<ge> U[i] (\<X> i)) \<and>
      (\<exists>i \<in> agents. U[i] (X' i) > U[i] (\<X> i))"
    using equili_feasible pareto_optimal_def
      pareto_dominating_def neg_as by auto
  have is_feasible: "feasible X' Y'"
    using xprime_pareto by blast
  have xprime_leq_y: "\<forall>i \<in> agents. (Price \<bullet> (X' i) \<ge>
    (Price \<bullet> \<E>[i]) + (\<Sum>j\<in>(firms). \<Theta>[i,j] *\<^sub>R (Price \<bullet> \<Y> j)))"
  proof
    fix i
    assume as: "i \<in> agents"
    have xprime_cons: "X' i \<in> consumption_set"
      by (simp add: all_larger_zero_in_csset)
    have x_leq_xprime: "U[i] (X' i) \<ge> U[i] (\<X> i)"
      using \<open>i \<in> agents\<close> xprime_pareto by blast
    have lns_pref: "local_nonsatiation consumption_set Pr[i]"
      using as assms by blast
    hence xprime_ge_x: "Price \<bullet> (X' i) \<ge> Price \<bullet> (\<X> i)"
      using x_leq_xprime xprime_cons as assms utility_ge_price_ge by blast
    then show  "Price \<bullet> (X' i) \<ge> (Price \<bullet> \<E>[i]) + (\<Sum>j\<in>(firms). \<Theta>[i,j] *\<^sub>R (Price \<bullet> \<Y> j))"
      using xprime_ge_x \<open>i \<in> agents\<close> lns_pref assms x_equil_x_ext_budget by fastforce
  qed
  have ex_greater_value : "\<exists>i \<in> agents. Price \<bullet> (X' i) > Price \<bullet> (\<X> i)"
  proof(rule ccontr)
    assume cpos : "\<not>(\<exists>i \<in> agents. Price \<bullet> (X' i) > Price \<bullet> (\<X> i))"
    obtain i where
      obt_witness : "i \<in> agents" "(U[i]) (X' i) > U[i] (\<X> i)"
      using xprime_pareto by blast
    show False
      by (metis cpos all_larger_zero_in_csset all_prefered_are_more_expensive
          inner_commute obt_witness(1) obt_witness(2) assms(2))
  qed
  have dom_g : "Price \<bullet> (\<Sum>i\<in>agents. X' i) > Price \<bullet> (\<Sum>i\<in>agents. (\<X> i))" (is "_ > _ \<bullet> ?x_sum")
  proof-
    have "(\<Sum>i\<in>agents. Price \<bullet> X' i) > (\<Sum>i\<in>agents. Price \<bullet> (\<X> i))"
      by (metis (mono_tags, lifting) xprime_leq_y assms ex_greater_value
          finite_nonepty_agents sum_strict_mono_ex1 x_equil_x_ext_budget)
    thus "Price \<bullet> (\<Sum>i\<in>agents. X' i) > Price \<bullet> ?x_sum"
      by (simp add: inner_sum_right)
  qed
  let ?y_sum = "(\<Sum>j\<in>firms. \<Y> j)"
  have equili_walras_law: "Price \<bullet> ?x_sum =
    (\<Sum>i\<in>agents. Price \<bullet> \<E>[i] + (\<Sum>j\<in>firms. \<Theta>[i,j] *\<^sub>R (Price \<bullet> \<Y> j)))" (is "_ = ?ws")
  proof-
    have "\<forall>i\<in>agents. Price \<bullet> \<X> i = Price \<bullet> \<E>[i] + (\<Sum>j\<in>firms. \<Theta>[i,j] *\<^sub>R (Price \<bullet> \<Y> j))"
      by (metis (no_types, lifting) assms x_equil_x_ext_budget)
    then show ?thesis
      by (simp add: inner_sum_right)
  qed
  also have remove_firm_pct: "... = Price \<bullet> (\<Sum>i\<in>agents. \<E>[i]) + (Price \<bullet> ?y_sum)"
  proof-
    have equals_inner_price:"0 = Price \<bullet> (?x_sum - ((\<Sum>i\<in>agents. \<E> i) + ?y_sum))"
      by (metis (no_types) diff_diff_add assms  walras_law)
    have "Price \<bullet> ?x_sum = Price \<bullet> ((\<Sum>i\<in>agents. \<E> i) + ?y_sum)"
      by (metis (no_types) equals_inner_price inner_diff_right right_minus_eq)
    then show ?thesis
      by (simp add: equili_walras_law inner_right_distrib)
  qed
  have xp_l_yp: "(\<Sum>i\<in>agents. X' i) \<le> (\<Sum>i\<in>agents. \<E>[i]) + (\<Sum>f\<in>firms. Y' f)"
    using feasible_def is_feasible by blast
  hence yprime_sgr_y: "Price \<bullet> (\<Sum>i\<in>agents. \<E>[i]) + Price \<bullet> (\<Sum>f\<in>firms. Y' f) > ?ws"
  proof -
    have "Price \<bullet> (\<Sum>i\<in>agents. X' i) \<le> Price \<bullet> ((\<Sum>i\<in>agents. \<E>[i]) + (\<Sum>j\<in>firms. Y' j))"
      by (metis xp_l_yp atLeastAtMost_iff inner_commute
          interval_inner_leI(2) less_imp_le order_refl price_cond)
    hence "?ws < Price \<bullet> ((\<Sum>i\<in>agents. \<E> i) + (\<Sum>j\<in>firms. Y' j))"
      using dom_g equili_walras_law by linarith
    then show ?thesis
      by (simp add: inner_right_distrib)
  qed
  have Y_is_optimum: "\<forall>j\<in>firms. \<forall>y \<in> production_sets j. Price \<bullet> \<Y> j \<ge> Price \<bullet> y"
    using assms prof_max_ge_all_in_pset by blast
  have yprime_in_prod_set: "\<forall>j \<in> firms. Y' j \<in> production_sets j"
    using feasible_def xprime_pareto  by blast
  hence "\<forall>j \<in> firms. \<forall>y \<in> production_sets j. Price \<bullet> \<Y> j \<ge> Price \<bullet> y"
    using Y_is_optimum by blast
  hence Y_ge_yprime: "\<forall>j \<in> firms. Price \<bullet> \<Y> j \<ge> Price \<bullet> Y' j"
    using yprime_in_prod_set by blast
  hence yprime_p_leq_Y: "Price \<bullet> (\<Sum>f\<in>firms. Y' f) \<le> Price \<bullet> ?y_sum"
    by (simp add: Y_ge_yprime inner_sum_right sum_mono)
  then show False
    using remove_firm_pct yprime_sgr_y by linarith
qed

text \<open> Equilibrium cannot be Pareto dominated. \<close>

lemma equilibria_dom_eachother:
  assumes "\<And>i. i \<in> agents \<Longrightarrow> local_nonsatiation consumption_set Pr[i]"
  assumes equil: "competitive_equilibrium Price \<X> \<Y>"
  shows "\<nexists>X' Y'. competitive_equilibrium P X' Y' \<and>
          X' \<succ>Pareto \<X>"
proof -
  have "pareto_optimal \<X> \<Y>"
    by (meson assms(1) equil first_welfare_theorem_priv_own)
  hence "\<nexists>X' Y'. feasible X' Y' \<and> X' \<succ>Pareto \<X>"
    using pareto_optimal_def by blast
  thus ?thesis
    by auto
qed

text \<open> Using monotonicity instead of local non-satiation proves the First Welfare Theorem. \<close>

corollary first_welfare_thm_monotone:
  assumes "\<forall>M \<in> carrier. (\<forall>x > M. x \<in> carrier)"
  assumes "\<And>i. i \<in> agents \<Longrightarrow> monotone_preference consumption_set Pr[i]"
  assumes "competitive_equilibrium Price \<X> \<Y>"
  shows "pareto_optimal \<X> \<Y>"
  using assms(2) assms(3) consumption_set_member first_welfare_theorem_priv_own
    unbounded_above_mono_imp_lns by blast

end

end