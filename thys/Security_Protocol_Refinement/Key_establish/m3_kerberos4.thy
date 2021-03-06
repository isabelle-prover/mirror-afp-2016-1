(*******************************************************************************

  Project: Development of Security Protocols by Refinement

  Module:  Key_establish/m3_kerberos4.thy (Isabelle/HOL 2016-1)
  ID:      $Id: m3_kerberos4.thy 132890 2016-12-24 10:25:57Z csprenge $
  Authors  Ivano Somaini, ETH Zurich <somainii@student.ethz.ch>
           Christoph Sprenger, ETH Zurich <sprenger@inf.ethz.ch>

  Key distribution protocols
  Third refinement: core Kerberos IV

  Copyright (c) 2009-2016 Ivano Somaini, Christoph Sprenger
  Licence: LGPL

*******************************************************************************)

section {* Core Kerberos 4 (L3) *}

theory m3_kerberos4 imports m2_kerberos "../Refinement/Message"
begin

text {* 
We model the core Kerberos 4 protocol:
\[
\begin{array}{lll}
  \mathrm{M1.} & A \rightarrow S: & A, B \\ 
  \mathrm{M2.} & S \rightarrow A: & \{Kab, B, Ts, Na, \{Kab, A, Ts\}_{Kbs} \}_{Kas} \\
  \mathrm{M3.} & A \rightarrow B: & \{A, Ta\}_{Kab}, \{Kab, A, Ts\}_{Kbs} \\
  \mathrm{M4.} & B \rightarrow A: & \{Ta\}_{Kab} \\
\end{array}
\]
*}

text {* Proof tool configuration. Avoid annoying automatic unfolding of
@{text "dom"}. *}

declare domIff [simp, iff del] 


(******************************************************************************)
subsection {* Setup *}
(******************************************************************************)

text {* Now we can define the initial key knowledge. *}

overloading ltkeySetup' \<equiv> ltkeySetup begin
definition ltkeySetup_def: "ltkeySetup' \<equiv> {(sharK C, A) | C A. A = C \<or> A = Sv}"
end

lemma corrKey_shrK_bad [simp]: "corrKey = shrK`bad"
by (auto simp add: keySetup_def ltkeySetup_def corrKey_def)


(******************************************************************************)
subsection {* State *}
(******************************************************************************)

text {* The secure channels are star-shaped to/from the server.  Therefore, 
we have only one agent in the relation. *}

record m3_state = "m1_state" +
  IK :: "msg set"                                -- {* intruder knowledge *}


text {* Observable state: 
@{term "runs"}, @{term "clk"}, and @{term "cache"}. *}

type_synonym 
  m3_obs = "m2_obs"

definition 
  m3_obs :: "m3_state \<Rightarrow> m3_obs" where
  "m3_obs s \<equiv> \<lparr> runs = runs s, leak = leak s, clk = clk s, cache = cache s \<rparr>"

type_synonym 
  m3_pred = "m3_state set"

type_synonym 
  m3_trans = "(m3_state \<times> m3_state) set"


(******************************************************************************)
subsection {* Events *}
(******************************************************************************)

text {* Protocol events. *}

definition     -- {* by @{term "A"}, refines @{term "m2_step1"} *}
  m3_step1 :: "[rid_t, agent, agent, nonce] \<Rightarrow> m3_trans"
where
  "m3_step1 Ra A B Na \<equiv> {(s, s1).
    (* guards: *)
    Ra \<notin> dom (runs s) \<and>                  (* Ra is fresh *)
    Na = Ra$na \<and>                          (* generated nonce *)

    (* actions: *)
    s1 = s\<lparr>
      runs := (runs s)(Ra \<mapsto> (Init, [A, B], [])),
      IK := insert {| Agent A, Agent B, Nonce Na |} (IK s)   (* send M1 *)
    \<rparr>
  }"

definition     -- {* by @{term "B"}, refines @{term "m2_step2"} *}
  m3_step2 :: "[rid_t, agent, agent] \<Rightarrow> m3_trans"
where
  "m3_step2 \<equiv> m1_step2"

definition     -- {* by @{text "Server"}, refines @{term m2_step3} *}
  m3_step3 :: "[rid_t, agent, agent, key, nonce, time] \<Rightarrow> m3_trans"
where
  "m3_step3 Rs A B Kab Na Ts \<equiv> {(s, s1).
    (* guards: *)
    Rs \<notin> dom (runs s) \<and>                          (* fresh server run *)
    Kab = sesK (Rs$sk) \<and>                          (* fresh session key *)

    {| Agent A, Agent B, Nonce Na |} \<in> IK s \<and>    (* recv M1 *)
    Ts = clk s \<and>                                 (* fresh timestamp *) 
   
    (* actions: *)
    (* record session key and send M2 *)
    s1 = s\<lparr>
      runs := (runs s)(Rs \<mapsto> (Serv, [A, B], [aNon Na, aNum Ts])), 
      IK := insert (Crypt (shrK A)                        (* send M2 *)
                     {| Key Kab, Agent B, Number Ts, Nonce Na, 
                        Crypt (shrK B) {| Key Kab, Agent A, Number Ts |} |})
               (IK s)
    \<rparr>
  }"

definition     -- {* by @{term "A"}, refines @{term m2_step4} *}
  m3_step4 :: "[rid_t, agent, agent, nonce, key, time, time, msg] \<Rightarrow> m3_trans"
where
  "m3_step4 Ra A B Na Kab Ts Ta X \<equiv> {(s, s1).

    (* guards: *)
     runs s Ra = Some (Init, [A, B], []) \<and>           (* key not yet recv'd *) 
     Na = Ra$na \<and>                                     (* generated nonce *)

     Crypt (shrK A)                                  (* recv M2 *)
       {| Key Kab, Agent B, Number Ts, Nonce Na, X |} \<in> IK s \<and> 

     (* read current time *)
     Ta = clk s \<and>

     (* check freshness of session key *)
     clk s < Ts + Ls \<and>

     (* actions: *)
     (* record session key and send M3 *)
     s1 = s\<lparr>
       runs := (runs s)(Ra \<mapsto> (Init, [A, B], [aKey Kab, aNum Ts, aNum Ta])),  
       IK := insert {| Crypt Kab {| Agent A, Number Ta |}, X |} (IK s)  (* M3 *)
     \<rparr>
  }"

definition     -- {* by @{term "B"}, refines @{term m2_step5} *}
  m3_step5 :: "[rid_t, agent, agent, key, time, time] \<Rightarrow> m3_trans"
where
  "m3_step5 Rb A B Kab Ts Ta \<equiv> {(s, s1). 
     (* guards: *)
     runs s Rb = Some (Resp, [A, B], []) \<and>             (* key not yet recv'd *)

     {| Crypt Kab {| Agent A, Number Ta |},                    (* recv M3 *)
        Crypt (shrK B) {| Key Kab, Agent A, Number Ts |} |} \<in> IK s \<and> 

     (* ensure freshness of session key *)
     clk s < Ts + Ls \<and>

     (* check authenticator's validity and replay; 'replays' with fresh authenticator ok! *)
     clk s < Ta + La \<and> 
     (B, Kab, Ta) \<notin> cache s \<and> 

     (* actions: *)
     (* record session key *)
     s1 = s\<lparr>
       runs := (runs s)(Rb \<mapsto> (Resp, [A, B], [aKey Kab, aNum Ts, aNum Ta])),
       cache := insert (B, Kab, Ta) (cache s),
       IK := insert (Crypt Kab (Number Ta)) (IK s)               (* send M4 *)
     \<rparr>
  }"

definition     -- {* by @{term "A"}, refines @{term m2_step6} *}
  m3_step6 :: "[rid_t, agent, agent, nonce, key, time, time] \<Rightarrow> m3_trans"
where
  "m3_step6 Ra A B Na Kab Ts Ta \<equiv> {(s, s'). 
     (* guards: *)
     runs s Ra = Some (Init, [A, B], [aKey Kab, aNum Ts, aNum Ta]) \<and>  (* knows key *)
     Na = Ra$na \<and>                                         (* generated nonce *)
     clk s < Ts + Ls \<and>                               (* check session key's recentness *)

     Crypt Kab (Number Ta) \<in> IK s \<and>                               (* recv M4 *)

     (* actions: *)
     s' = s\<lparr>
        runs := (runs s)(Ra \<mapsto> (Init, [A, B], [aKey Kab, aNum Ts, aNum Ta, END]))
     \<rparr>
  }"

text {* Clock tick event *}

definition   -- {* refines @{term "m2_tick"} *}
  m3_tick :: "time \<Rightarrow> m3_trans" 
where
  "m3_tick \<equiv> m1_tick"


text {* Purge event: purge cache of expired timestamps *}

definition     -- {* refines @{term "m2_purge"} *}
  m3_purge :: "agent \<Rightarrow> m3_trans" 
where
  "m3_purge \<equiv> m1_purge"


text {* Session key compromise. *}

definition     -- {* refines @{term m2_leak} *} 
  m3_leak :: "[rid_t, agent, agent, nonce, time] \<Rightarrow> m3_trans"
where
  "m3_leak Rs A B Na Ts \<equiv> {(s, s1).
    (* guards: *) 
    runs s Rs = Some (Serv, [A, B], [aNon Na, aNum Ts]) \<and> 
    (clk s \<ge> Ts + Ls) \<and>             (* only compromise 'old' session keys! *)

    (* actions: *)
    (* record session key as leaked and add it to intruder knowledge *)
    s1 = s\<lparr> leak := insert (sesK (Rs$sk), A, B, Na, Ts) (leak s), 
            IK := insert (Key (sesK (Rs$sk))) (IK s) \<rparr> 
  }"


text {* Intruder fake event. The following "Dolev-Yao" event generates all 
intruder-derivable messages. *}

definition     -- {* refines @{term "m2_fake"} *}
  m3_DY_fake :: "m3_trans"
where
  "m3_DY_fake \<equiv> {(s, s1).
     
     (* actions: *)
     s1 = s\<lparr> IK := synth (analz (IK s)) \<rparr>       (* take DY closure *)
  }"


(******************************************************************************)
subsection {* Transition system *}
(******************************************************************************)

definition 
  m3_init :: "m3_pred"
where
  "m3_init \<equiv> { \<lparr> 
     runs = empty, 
     leak = shrK`bad \<times> {undefined}, 
     clk = 0, 
     cache = {}, 
     IK = Key`shrK`bad 
  \<rparr> }"

definition 
  m3_trans :: "m3_trans" where
  "m3_trans \<equiv> (\<Union>A B Ra Rb Rs Na Kab Ts Ta T X.
     m3_step1 Ra A B Na \<union>
     m3_step2 Rb A B \<union>
     m3_step3 Rs A B Kab Na Ts \<union>
     m3_step4 Ra A B Na Kab Ts Ta X \<union>
     m3_step5 Rb A B Kab Ts Ta \<union>
     m3_step6 Ra A B Na Kab Ts Ta \<union>
     m3_tick T \<union>
     m3_purge A \<union> 
     m3_leak Rs A B Na Ts \<union>
     m3_DY_fake \<union>
     Id
  )"

definition 
  m3 :: "(m3_state, m3_obs) spec" where
  "m3 \<equiv> \<lparr>
    init = m3_init,
    trans = m3_trans,
    obs = m3_obs
  \<rparr>"

lemmas m3_loc_defs = 
  m3_def m3_init_def m3_trans_def m3_obs_def
  m3_step1_def m3_step2_def m3_step3_def m3_step4_def m3_step5_def 
  m3_step6_def m3_tick_def m3_purge_def m3_leak_def m3_DY_fake_def

lemmas m3_defs = m3_loc_defs m2_defs


(******************************************************************************)
subsection {* Invariants *}
(******************************************************************************)

text {* Specialized injection that we can apply more aggressively. *}

lemmas analz_Inj_IK = analz.Inj [where H="IK s" for s] 
lemmas parts_Inj_IK = parts.Inj [where H="IK s" for s] 

declare parts_Inj_IK [dest!]

declare analz_into_parts [dest]


subsubsection {* inv4: Secrecy of pre-distributed shared keys *}
(*inv**************************************************************************)

definition 
  m3_inv4_lkeysec :: "m3_pred" 
where
  "m3_inv4_lkeysec \<equiv> {s. \<forall>C.
     (Key (shrK C) \<in> parts (IK s) \<longrightarrow> C \<in> bad) \<and>
     (C \<in> bad \<longrightarrow> Key (shrK C) \<in> IK s)
  }"

lemmas m3_inv4_lkeysecI = m3_inv4_lkeysec_def [THEN setc_def_to_intro, rule_format]
lemmas m3_inv4_lkeysecE [elim] = m3_inv4_lkeysec_def [THEN setc_def_to_elim, rule_format]
lemmas m3_inv4_lkeysecD = m3_inv4_lkeysec_def [THEN setc_def_to_dest, rule_format]


text {* Invariance proof. *}

lemma PO_m3_inv4_lkeysec_init [iff]:
  "init m3 \<subseteq> m3_inv4_lkeysec"
by (auto simp add: m3_defs intro!: m3_inv4_lkeysecI)

lemma PO_m3_inv4_lkeysec_trans [iff]:
  "{m3_inv4_lkeysec} trans m3 {> m3_inv4_lkeysec}"
by (auto simp add: PO_hoare_defs m3_defs intro!: m3_inv4_lkeysecI)
   (auto dest!: Body)

lemma PO_m3_inv4_lkeysec [iff]: "reach m3 \<subseteq> m3_inv4_lkeysec"
by (rule inv_rule_incr) (fast+)


text {* Useful simplifier lemmas *}

lemma m3_inv4_lkeysec_for_parts [simp]:
  "\<lbrakk> s \<in> m3_inv4_lkeysec \<rbrakk> \<Longrightarrow> Key (shrK C) \<in> parts (IK s) \<longleftrightarrow> C \<in> bad"
by auto

lemma m3_inv4_lkeysec_for_analz [simp]:
  "\<lbrakk> s \<in> m3_inv4_lkeysec \<rbrakk> \<Longrightarrow> Key (shrK C) \<in> analz (IK s) \<longleftrightarrow> C \<in> bad"
by auto


subsubsection {* inv6: Ticket shape for honestly encrypted M2 *}
(*inv**************************************************************************)

definition 
  m3_inv6_ticket :: "m3_pred" 
where
  "m3_inv6_ticket \<equiv> {s. \<forall>A B T K N X.
     A \<notin> bad \<longrightarrow> 
     Crypt (shrK A) {| Key K, Agent B, Number T, Nonce N, X |} \<in> parts (IK s) \<longrightarrow>
       X = Crypt (shrK B) {| Key K, Agent A, Number T |} \<and> K \<in> range sesK
  }"

lemmas m3_inv6_ticketI = m3_inv6_ticket_def [THEN setc_def_to_intro, rule_format]
lemmas m3_inv6_ticketE [elim] = m3_inv6_ticket_def [THEN setc_def_to_elim, rule_format]
lemmas m3_inv6_ticketD = m3_inv6_ticket_def [THEN setc_def_to_dest, rule_format, rotated -1]


text {* Invariance proof. *}

lemma PO_m3_inv6_ticket_init [iff]:
  "init m3 \<subseteq> m3_inv6_ticket"
by (auto simp add: m3_defs intro!: m3_inv6_ticketI)

lemma PO_m3_inv6_ticket_trans [iff]:
  "{m3_inv6_ticket \<inter> m3_inv4_lkeysec} trans m3 {> m3_inv6_ticket}"
apply (auto simp add: PO_hoare_defs m3_defs intro!: m3_inv6_ticketI)
apply (auto dest: m3_inv6_ticketD)
-- {* 2 subgoals *}
apply (drule parts_cut, drule Body, auto dest: m3_inv6_ticketD)+
done

lemma PO_m3_inv6_ticket [iff]: "reach m3 \<subseteq> m3_inv6_ticket"
by (rule inv_rule_incr) (auto del: subsetI)


subsubsection {* inv7: Session keys not used to encrypt other session keys *}
(*inv**************************************************************************)

text {* Session keys are not used to encrypt other keys. Proof requires
generalization to sets of session keys.  

NOTE: For Kerberos 4, this invariant cannot be inherited from the corresponding 
L2 invariant. The simulation relation is only an implication not an equivalence.
*}

definition 
  m3_inv7a_sesK_compr :: "m3_pred"
where
  "m3_inv7a_sesK_compr \<equiv> {s. \<forall>K KK.
     KK \<subseteq> range sesK \<longrightarrow>
     (Key K \<in> analz (Key`KK \<union> (IK s))) = (K \<in> KK \<or> Key K \<in> analz (IK s)) 
  }"

lemmas m3_inv7a_sesK_comprI = m3_inv7a_sesK_compr_def [THEN setc_def_to_intro, rule_format]
lemmas m3_inv7a_sesK_comprE = m3_inv7a_sesK_compr_def [THEN setc_def_to_elim, rule_format]
lemmas m3_inv7a_sesK_comprD = m3_inv7a_sesK_compr_def [THEN setc_def_to_dest, rule_format]

text {* Additional lemma *}
lemmas insert_commute_Key = insert_commute [where x="Key K" for K] 

lemmas m3_inv7a_sesK_compr_simps = 
  m3_inv7a_sesK_comprD 
  m3_inv7a_sesK_comprD [where KK="insert Kab KK" for Kab KK, simplified]
  m3_inv7a_sesK_comprD [where KK="{Kab}" for Kab, simplified]
  insert_commute_Key


text {* Invariance proof. *}

lemma PO_m3_inv7a_sesK_compr_step4:
  "{m3_inv7a_sesK_compr \<inter> m3_inv6_ticket \<inter> m3_inv4_lkeysec} 
      m3_step4 Ra A B Na Kab Ts Ta X  
   {> m3_inv7a_sesK_compr}"
proof - 
  { fix K KK s
    assume H:
      "s \<in> m3_inv4_lkeysec" "s \<in> m3_inv7a_sesK_compr" "s \<in> m3_inv6_ticket" 
      "runs s Ra = Some (Init, [A, B], [])"
      "Na = Ra$na"
      "KK \<subseteq> range sesK" 
      "Crypt (shrK A) \<lbrace>Key Kab, Agent B, Number Ts, Nonce Na, X\<rbrace> \<in> analz (IK s)"
    have
      "(Key K \<in> analz (insert X (Key ` KK \<union> IK s))) =
          (K \<in> KK \<or> Key K \<in> analz (insert X (IK s)))"
    proof (cases "A \<in> bad")
      case True 
        with H have "X \<in> analz (IK s)" by (auto dest!: Decrypt)
      moreover
        with H have "X \<in> analz (Key ` KK \<union> IK s)" 
        by (auto intro: analz_monotonic)
      ultimately show ?thesis using H
        by (auto simp add: m3_inv7a_sesK_compr_simps analz_insert_eq)
    next
      case False thus ?thesis using H
      by (fastforce simp add: m3_inv7a_sesK_compr_simps 
                    dest!: m3_inv6_ticketD [OF analz_into_parts])
    qed
  }
  thus ?thesis 
  by (auto simp add: PO_hoare_defs m3_defs intro!: m3_inv7a_sesK_comprI dest!: analz_Inj_IK)
qed

text {* All together now. *}

lemmas PO_m3_inv7a_sesK_compr_trans_lemmas = 
  PO_m3_inv7a_sesK_compr_step4 

lemma PO_m3_inv7a_sesK_compr_init [iff]:
  "init m3 \<subseteq> m3_inv7a_sesK_compr"
by (auto simp add: m3_defs intro!: m3_inv7a_sesK_comprI)

lemma PO_m3_inv7a_sesK_compr_trans [iff]:
  "{m3_inv7a_sesK_compr \<inter> m3_inv6_ticket \<inter> m3_inv4_lkeysec} 
     trans m3 
   {> m3_inv7a_sesK_compr}"
by (auto simp add: m3_def m3_trans_def intro!: PO_m3_inv7a_sesK_compr_trans_lemmas)
   (auto simp add: PO_hoare_defs m3_defs m3_inv7a_sesK_compr_simps intro!: m3_inv7a_sesK_comprI)

lemma PO_m3_inv7a_sesK_compr [iff]: "reach m3 \<subseteq> m3_inv7a_sesK_compr"
by (rule_tac J="m3_inv6_ticket \<inter> m3_inv4_lkeysec" in inv_rule_incr) (auto)


subsubsection {* inv7b: Session keys not used to encrypt nonces *}
(*inv**************************************************************************)

text {* Session keys are not used to encrypt nonces. The proof requires a
generalization to sets of session keys.  *}

definition 
  m3_inv7b_sesK_compr_non :: "m3_pred"
where
  "m3_inv7b_sesK_compr_non \<equiv> {s. \<forall>N KK.
     KK \<subseteq> range sesK \<longrightarrow> (Nonce N \<in> analz (Key`KK \<union> (IK s))) = (Nonce N \<in> analz (IK s))
  }"

lemmas m3_inv7b_sesK_compr_nonI = m3_inv7b_sesK_compr_non_def [THEN setc_def_to_intro, rule_format]
lemmas m3_inv7b_sesK_compr_nonE = m3_inv7b_sesK_compr_non_def [THEN setc_def_to_elim, rule_format]
lemmas m3_inv7b_sesK_compr_nonD = m3_inv7b_sesK_compr_non_def [THEN setc_def_to_dest, rule_format]

lemmas m3_inv7b_sesK_compr_non_simps = 
  m3_inv7b_sesK_compr_nonD 
  m3_inv7b_sesK_compr_nonD [where KK="insert Kab KK" for Kab KK, simplified]
  m3_inv7b_sesK_compr_nonD [where KK="{Kab}" for Kab, simplified]
  insert_commute_Key


text {* Invariance proof. *}

lemma PO_m3_inv7b_sesK_compr_non_step3:
  "{m3_inv7b_sesK_compr_non} m3_step3 Rs A B Kab Na Ts {> m3_inv7b_sesK_compr_non}"
by (auto simp add: PO_hoare_defs m3_defs m3_inv7b_sesK_compr_non_simps  
         intro!: m3_inv7b_sesK_compr_nonI dest!: analz_Inj_IK)

lemma PO_m3_inv7b_sesK_compr_non_step4:
  "{m3_inv7b_sesK_compr_non \<inter> m3_inv6_ticket \<inter> m3_inv4_lkeysec} 
      m3_step4 Ra A B Na Kab Ts Ta X  
   {> m3_inv7b_sesK_compr_non}"
proof - 
  { fix N KK s
    assume H:
      "s \<in> m3_inv4_lkeysec""s \<in> m3_inv7b_sesK_compr_non" 
      "s \<in> m3_inv6_ticket" 
      "runs s Ra = Some (Init, [A, B], [])"
      "Na = Ra$na"
      "KK \<subseteq> range sesK" 
      "Crypt (shrK A) \<lbrace>Key Kab, Agent B, Number Ts, Nonce Na, X\<rbrace> \<in> analz (IK s)"
    have
      "(Nonce N \<in> analz (insert X (Key ` KK \<union> IK s))) =
          (Nonce N \<in> analz (insert X (IK s)))"
    proof (cases)
      assume "A \<in> bad" show ?thesis 
      proof -
        from `A \<in> bad` have "X \<in> analz (IK s)" using H
        by (auto dest!: Decrypt)
      moreover
        hence "X \<in> analz (Key ` KK \<union> IK s)" 
        by (auto intro: analz_monotonic)
      ultimately show ?thesis using H
        by (auto simp add: m3_inv7b_sesK_compr_non_simps analz_insert_eq)
      qed
    next
      assume "A \<notin> bad" thus ?thesis using H
      by (fastforce simp add: m3_inv7b_sesK_compr_non_simps 
                    dest!: m3_inv6_ticketD [OF analz_into_parts])
    qed
  }
  thus ?thesis 
  by (auto simp add: PO_hoare_defs m3_defs intro!: m3_inv7b_sesK_compr_nonI
           dest!: analz_Inj_IK)
qed


text {* All together now. *}

lemmas PO_m3_inv7b_sesK_compr_non_trans_lemmas = 
  PO_m3_inv7b_sesK_compr_non_step3 PO_m3_inv7b_sesK_compr_non_step4 

lemma PO_m3_inv7b_sesK_compr_non_init [iff]:
  "init m3 \<subseteq> m3_inv7b_sesK_compr_non"
by (auto simp add: m3_defs intro!: m3_inv7b_sesK_compr_nonI)

lemma PO_m3_inv7b_sesK_compr_non_trans [iff]:
  "{m3_inv7b_sesK_compr_non \<inter> m3_inv6_ticket \<inter> m3_inv4_lkeysec} 
     trans m3 
   {> m3_inv7b_sesK_compr_non}"
by (auto simp add: m3_def m3_trans_def intro!: PO_m3_inv7b_sesK_compr_non_trans_lemmas)
   (auto simp add: PO_hoare_defs m3_defs m3_inv7b_sesK_compr_non_simps 
                   intro!: m3_inv7b_sesK_compr_nonI)

lemma PO_m3_inv7b_sesK_compr_non [iff]: "reach m3 \<subseteq> m3_inv7b_sesK_compr_non"
by (rule_tac J="m3_inv6_ticket \<inter> m3_inv4_lkeysec" in inv_rule_incr) 
   (auto)


(******************************************************************************)
subsection {* Refinement *}
(******************************************************************************)

subsubsection {* Message abstraction and simulation relation *}
(******************************************************************************)

text {* Abstraction function on sets of messages. *}

inductive_set 
  abs_msg :: "msg set \<Rightarrow> chmsg set"
  for H :: "msg set"
where 
  am_M1: 
    "{| Agent A, Agent B, Nonce N |} \<in> H
  \<Longrightarrow> Insec A B (Msg [aNon N]) \<in> abs_msg H"
| am_M2a:
    "Crypt (shrK C) {| Key K, Agent B, Number T, Nonce N, X |} \<in> H 
  \<Longrightarrow> Secure Sv C (Msg [aKey K, aAgt B, aNum T, aNon N]) \<in> abs_msg H"
| am_M2b: 
    "Crypt (shrK C) {| Key K,  Agent A, Number T |} \<in> H 
  \<Longrightarrow> Secure Sv C (Msg [aKey K, aAgt A, aNum T]) \<in> abs_msg H"
| am_M3: 
    "Crypt K {| Agent A, Number T |} \<in> H 
  \<Longrightarrow> dAuth K (Msg [aAgt A, aNum T]) \<in> abs_msg H"
| am_M4: 
    "Crypt K (Number T) \<in> H 
  \<Longrightarrow> dAuth K (Msg [aNum T]) \<in> abs_msg H"


text {* R23: The simulation relation. This is a data refinement of 
the insecure and secure channels of refinement 2. *}

definition
  R23_msgs :: "(m2_state \<times> m3_state) set" where
  "R23_msgs \<equiv> {(s, t). abs_msg (parts (IK t)) \<subseteq> chan s }"

definition
  R23_keys :: "(m2_state \<times> m3_state) set" where
  "R23_keys \<equiv> {(s, t). \<forall>KK K. KK \<subseteq> range sesK \<longrightarrow> 
     Key K \<in> analz (Key`KK \<union> (IK t)) \<longrightarrow> aKey K \<in> extr (aKey`KK \<union> ik0) (chan s)
  }" 

definition 
  R23_non :: "(m2_state \<times> m3_state) set" where
  "R23_non \<equiv> {(s, t). \<forall>KK N. KK \<subseteq> range sesK \<longrightarrow> 
     Nonce N \<in> analz (Key`KK \<union> (IK t)) \<longrightarrow> aNon N \<in> extr (aKey`KK \<union> ik0) (chan s)
  }"

definition 
  R23_pres :: "(m2_state \<times> m3_state) set" where
  "R23_pres \<equiv> {(s, t). runs s = runs t \<and> leak s = leak t \<and> clk s = clk t \<and> cache s = cache t}"

definition
  R23 :: "(m2_state \<times> m3_state) set" where
  "R23 \<equiv> R23_msgs \<inter> R23_keys \<inter> R23_non \<inter> R23_pres"

lemmas R23_defs = 
  R23_def R23_msgs_def R23_keys_def R23_non_def R23_pres_def


text {* The mediator function is the identity here. *}

definition 
  med32 :: "m3_obs \<Rightarrow> m2_obs" where
  "med32 \<equiv> id"


lemmas R23_msgsI = R23_msgs_def [THEN rel_def_to_intro, simplified, rule_format]
lemmas R23_msgsE [elim] = R23_msgs_def [THEN rel_def_to_elim, simplified, rule_format]
lemmas R23_msgsE' [elim] =
  R23_msgs_def [THEN rel_def_to_dest, simplified, rule_format, THEN subsetD]

lemmas R23_keysI = R23_keys_def [THEN rel_def_to_intro, simplified, rule_format]
lemmas R23_keysE [elim] = R23_keys_def [THEN rel_def_to_elim, simplified, rule_format]
lemmas R23_keysD = R23_keys_def [THEN rel_def_to_dest, simplified, rule_format, rotated 2]

lemmas R23_nonI = R23_non_def [THEN rel_def_to_intro, simplified, rule_format]
lemmas R23_nonE [elim] = R23_non_def [THEN rel_def_to_elim, simplified, rule_format]
lemmas R23_nonD = R23_non_def [THEN rel_def_to_dest, simplified, rule_format, rotated 2]

lemmas R23_presI = R23_pres_def [THEN rel_def_to_intro, simplified, rule_format]
lemmas R23_presE [elim] = R23_pres_def [THEN rel_def_to_elim, simplified, rule_format]

lemmas R23_intros = R23_msgsI R23_keysI R23_nonI R23_presI


text {* Lemmas for various instantiations (keys and nonces). *}

lemmas R23_keys_dests = 
  R23_keysD
  R23_keysD [where KK="{}", simplified]
  R23_keysD [where KK="{K}" for K, simplified]
  R23_keysD [where KK="insert K KK" for K KK, simplified, OF _ _ conjI]

lemmas R23_non_dests = 
  R23_nonD
  R23_nonD [where KK="{}", simplified]
  R23_nonD [where KK="{K}" for K, simplified]
  R23_nonD [where KK="insert K KK" for K KK, simplified, OF _ _ conjI]

lemmas R23_dests = R23_keys_dests R23_non_dests 


subsubsection {* General lemmas *}
(******************************************************************************)

text {* General facts about @{term "abs_msg"} *}

declare abs_msg.intros [intro!] 
declare abs_msg.cases [elim!]

lemma abs_msg_empty: "abs_msg {} = {}"
by (auto)

lemma abs_msg_Un [simp]: 
  "abs_msg (G \<union> H) = abs_msg G \<union> abs_msg H"
by (auto)

lemma abs_msg_mono [elim]: 
  "\<lbrakk> m \<in> abs_msg G; G \<subseteq> H \<rbrakk> \<Longrightarrow> m \<in> abs_msg H"
by (auto)

lemma abs_msg_insert_mono [intro]: 
  "\<lbrakk> m \<in> abs_msg H \<rbrakk> \<Longrightarrow> m \<in> abs_msg (insert m' H)"
by (auto)


text {* Facts about @{term "abs_msg"} concerning abstraction of fakeable 
messages. This is crucial for proving the refinement of the intruder event. *}

lemma abs_msg_DY_subset_fakeable:
  "\<lbrakk> (s, t) \<in> R23_msgs; (s, t) \<in> R23_keys; (s, t) \<in> R23_non; t \<in> m3_inv4_lkeysec \<rbrakk>
  \<Longrightarrow> abs_msg (synth (analz (IK t))) \<subseteq> fake ik0 (dom (runs s)) (chan s)"
apply (auto)
-- {* 9 subgoals, deal with replays first *}
prefer 2 apply (blast) 
prefer 3 apply (blast)
prefer 4 apply (blast)
prefer 5 apply (blast)
-- {* remaining 5 subgoals are real fakes *}
apply (intro fake_StatCh fake_DynCh, auto dest: R23_dests)+
done


subsubsection {* Refinement proof *}
(******************************************************************************)

text {* Pair decomposition. These were set to \texttt{elim!}, which is too
agressive here. *} 

declare MPair_analz [rule del, elim]
declare MPair_parts [rule del, elim]


text {* Protocol events. *}

lemma PO_m3_step1_refines_m2_step1:
  "{R23} 
     (m2_step1 Ra A B Na), (m3_step1 Ra A B Na) 
   {> R23}"
by (auto simp add: PO_rhoare_defs R23_def m3_defs intro!: R23_intros)
   (auto)

lemma PO_m3_step2_refines_m2_step2:
  "{R23} 
     (m2_step2 Rb A B), (m3_step2 Rb A B)
   {> R23}"
by (auto simp add: PO_rhoare_defs R23_def m3_defs intro!: R23_intros)

lemma PO_m3_step3_refines_m2_step3:
  "{R23 \<inter> (m2_inv3a_sesK_compr) \<times> (m3_inv7a_sesK_compr \<inter> m3_inv4_lkeysec)} 
     (m2_step3 Rs A B Kab Na Ts), (m3_step3 Rs A B Kab Na Ts)
   {> R23}"
proof -
  { fix s t
    assume H:
      "(s, t) \<in> R23_msgs" "(s, t) \<in> R23_keys" "(s, t) \<in> R23_non" 
      "(s, t) \<in> R23_pres"
      "s \<in> m2_inv3a_sesK_compr" 
      "t \<in> m3_inv7a_sesK_compr" "t \<in> m3_inv4_lkeysec"
      "Kab = sesK (Rs$sk)" "Rs \<notin> dom (runs t)"
      "\<lbrace>Agent A, Agent B, Nonce Na\<rbrace> \<in> parts (IK t)"
    let ?s'=
      "s\<lparr> runs := runs s(Rs \<mapsto> (Serv, [A, B], [aNon Na, aNum (clk t)])),
          chan := insert (Secure Sv A (Msg [aKey Kab, aAgt B, aNum (clk t), aNon Na])) 
                 (insert (Secure Sv B (Msg [aKey Kab, aAgt A, aNum (clk t)])) (chan s)) \<rparr>"
    let ?t'=
      "t\<lparr> runs := runs t(Rs \<mapsto> (Serv, [A, B], [aNon Na, aNum (clk t)])),
          IK := insert 
                  (Crypt (shrK A) 
                     \<lbrace> Key Kab, Agent B, Number (clk t), Nonce Na,
                       Crypt (shrK B) \<lbrace> Key Kab, Agent A, Number (clk t) \<rbrace>\<rbrace>)
                  (IK t) \<rparr>"
  -- {* here we go *}
    have "(?s', ?t') \<in> R23_msgs" using H
    by (-) (rule R23_intros, auto)  
  moreover
    have "(?s', ?t') \<in> R23_keys" using H
    by (-) (rule R23_intros, 
            auto simp add: m2_inv3a_sesK_compr_simps m3_inv7a_sesK_compr_simps dest: R23_keys_dests)
  moreover
    have "(?s', ?t') \<in> R23_non" using H
    by (-) (rule R23_intros, 
            auto simp add: m2_inv3a_sesK_compr_simps m3_inv7a_sesK_compr_simps dest: R23_non_dests)
  moreover
    have "(?s', ?t') \<in> R23_pres" using H
    by (-) (rule R23_intros, auto)  
  moreover
    note calculation
  }
  thus ?thesis
  by (auto simp add: PO_rhoare_defs R23_def m3_defs) 
qed

lemma PO_m3_step4_refines_m2_step4:
  "{R23 \<inter> (UNIV) 
        \<times> (m3_inv7a_sesK_compr \<inter> m3_inv7b_sesK_compr_non \<inter> m3_inv6_ticket \<inter> m3_inv4_lkeysec)} 
     (m2_step4 Ra A B Na Kab Ts Ta), (m3_step4 Ra A B Na Kab Ts Ta X)  
   {> R23}"
proof -
  { fix s t 
    assume H:
      "(s, t) \<in> R23_msgs" "(s, t) \<in> R23_keys" "(s, t) \<in> R23_non" "(s, t) \<in> R23_pres" 
      "t \<in> m3_inv7a_sesK_compr" "t \<in> m3_inv7b_sesK_compr_non" 
      "t \<in> m3_inv6_ticket" "t \<in> m3_inv4_lkeysec"
      "runs t Ra = Some (Init, [A, B], [])"
      "Na = Ra$na"
      "Crypt (shrK A) \<lbrace>Key Kab, Agent B, Number Ts, Nonce Na, X\<rbrace> \<in> analz (IK t)"
    let ?s' = "s\<lparr> runs := runs s(Ra \<mapsto> (Init, [A, B], [aKey Kab, aNum Ts, aNum (clk t)])),
                 chan := insert (dAuth Kab (Msg [aAgt A, aNum (clk t)])) (chan s) \<rparr>" 
    and ?t' = "t\<lparr> runs := runs t(Ra \<mapsto> (Init, [A, B], [aKey Kab, aNum Ts, aNum (clk t)])),
                 IK := insert \<lbrace> Crypt Kab \<lbrace>Agent A, Number (clk t)\<rbrace>, X \<rbrace> (IK t) \<rparr>" 
    from H have
      "Secure Sv A (Msg [aKey Kab, aAgt B, aNum Ts, aNon Na]) \<in> chan s" 
    by (auto)  
  moreover
    have "X \<in> parts (IK t)" using H by (auto dest!: Body MPair_parts)
    hence "(?s', ?t') \<in> R23_msgs" using H by (auto intro!: R23_intros) (auto)
  moreover
    have "(?s', ?t') \<in> R23_keys" 
    proof (cases)
      assume "A \<in> bad" 
      with H have "X \<in> analz (IK t)" by (-) (drule Decrypt, auto)
      with H show ?thesis 
        by (-) (rule R23_intros, auto dest!: analz_cut intro: analz_monotonic)
    next
      assume "A \<notin> bad" show ?thesis
      proof -
        note H
        moreover
        with `A \<notin> bad` 
        have "X = Crypt (shrK B) \<lbrace>Key Kab, Agent A, Number Ts \<rbrace> \<and> Kab \<in> range sesK" 
          by (auto dest!: m3_inv6_ticketD)
        moreover
        { assume H1: "Key (shrK B) \<in> analz (IK t)"
          have "aKey Kab \<in> extr ik0 (chan s)" 
          proof -
            note calculation
            moreover
            hence "Secure Sv B (Msg [aKey Kab, aAgt A, aNum Ts]) \<in> chan s" 
              by (-) (drule analz_into_parts, drule Body, elim MPair_parts, auto)
            ultimately
            show ?thesis using H1 by auto
          qed 
        }
        ultimately show ?thesis 
          by (-) (rule R23_intros, auto simp add: m3_inv7a_sesK_compr_simps)
      qed
    qed
  moreover
    have "(?s', ?t') \<in> R23_non"
    proof (cases)
      assume "A \<in> bad"
      hence "X \<in> analz (IK t)" using H by (-) (drule Decrypt, auto)
      thus ?thesis using H
        by (-) (rule R23_intros, auto dest!: analz_cut intro: analz_monotonic)
    next
      assume "A \<notin> bad" 
      hence "X = Crypt (shrK B) \<lbrace>Key Kab, Agent A, Number Ts \<rbrace> \<and> Kab \<in> range sesK" using H
        by (auto dest!: m3_inv6_ticketD) 
      thus ?thesis using H
        by (-) (rule R23_intros, 
                auto simp add: m3_inv7a_sesK_compr_simps m3_inv7b_sesK_compr_non_simps)
    qed 
  moreover
    have "(?s', ?t') \<in> R23_pres" using H
    by (auto intro!: R23_intros)
  moreover
    note calculation
  }
  thus ?thesis 
  by (auto simp add: PO_rhoare_defs R23_def m3_defs dest!: analz_Inj_IK)
qed

lemma PO_m3_step5_refines_m2_step5:
  "{R23} 
     (m2_step5 Rb A B Kab Ts Ta), (m3_step5 Rb A B Kab Ts Ta) 
   {> R23}"
by (auto simp add: PO_rhoare_defs R23_def m3_defs intro!: R23_intros)
   (auto) 

lemma PO_m3_step6_refines_m2_step6:
  "{R23} 
     (m2_step6 Ra A B Na Kab Ts Ta), (m3_step6 Ra A B Na Kab Ts Ta) 
   {> R23}"
by (auto simp add: PO_rhoare_defs R23_def m3_defs intro!: R23_intros)

lemma PO_m3_tick_refines_m2_tick:
  "{R23}
    (m2_tick T), (m3_tick T)
   {>R23}"
by (auto simp add: PO_rhoare_defs R23_def m3_defs intro!: R23_intros)

lemma PO_m3_purge_refines_m2_purge:
  "{R23}
     (m2_purge A), (m3_purge A)
   {>R23}"
by (auto simp add: PO_rhoare_defs R23_def m3_defs intro!: R23_intros)


text {* Intruder events. *}

lemma PO_m3_leak_refines_m2_leak:
  "{R23}
     (m2_leak Rs A B Na Ts), (m3_leak Rs A B Na Ts)
   {>R23}"
by (auto simp add: PO_rhoare_defs R23_def m3_defs intro!: R23_intros)
   (auto dest: R23_dests)

lemma PO_m3_DY_fake_refines_m2_fake:
  "{R23 \<inter> UNIV \<times> (m3_inv4_lkeysec)} 
     m2_fake, m3_DY_fake
   {> R23}"
apply (auto simp add: PO_rhoare_defs R23_def m3_defs intro!: R23_intros 
            del: abs_msg.cases)
apply (auto intro: abs_msg_DY_subset_fakeable [THEN subsetD]
            del: abs_msg.cases)
apply (auto dest: R23_dests)
done


text {* All together now... *}

lemmas PO_m3_trans_refines_m2_trans = 
  PO_m3_step1_refines_m2_step1 PO_m3_step2_refines_m2_step2
  PO_m3_step3_refines_m2_step3 PO_m3_step4_refines_m2_step4
  PO_m3_step5_refines_m2_step5 PO_m3_step6_refines_m2_step6 
  PO_m3_tick_refines_m2_tick PO_m3_purge_refines_m2_purge
  PO_m3_leak_refines_m2_leak PO_m3_DY_fake_refines_m2_fake


lemma PO_m3_refines_init_m2 [iff]:
  "init m3 \<subseteq> R23``(init m2)"
by (auto simp add: R23_def m3_defs intro!: R23_intros)

lemma PO_m3_refines_trans_m2 [iff]:
  "{R23 \<inter> (m2_inv3a_sesK_compr) 
        \<times> (m3_inv7a_sesK_compr \<inter> m3_inv7b_sesK_compr_non \<inter> m3_inv6_ticket \<inter> m3_inv4_lkeysec)} 
     (trans m2), (trans m3) 
   {> R23}"
by (auto simp add: m3_def m3_trans_def m2_def m2_trans_def)
   (blast intro!: PO_m3_trans_refines_m2_trans)+

lemma PO_m3_observation_consistent [iff]:
  "obs_consistent R23 med32 m2 m3"
by (auto simp add: obs_consistent_def R23_def med32_def m3_defs)


text {* Refinement result. *}

lemma m3_refines_m2 [iff]:
  "refines 
     (R23 \<inter> 
      (m2_inv3a_sesK_compr) \<times> 
      (m3_inv7a_sesK_compr \<inter> m3_inv7b_sesK_compr_non \<inter> m3_inv6_ticket \<inter> m3_inv4_lkeysec)) 
     med32 m2 m3"
by (rule Refinement_using_invariants) (auto) 

lemma m3_implements_m2 [iff]:
  "implements med32 m2 m3"
by (rule refinement_soundness) (auto)


subsection {* Inherited invariants *}
(******************************************************************************)

subsubsection {* inv3 (derived): Key secrecy for initiator *}
(*invh*************************************************************************)

definition 
  m3_inv3_ikk_init :: "m3_state set"
where
  "m3_inv3_ikk_init \<equiv> {s. \<forall>A B Ra K Ts nl.
     runs s Ra = Some (Init, [A, B], aKey K # aNum Ts # nl) \<longrightarrow> A \<in> good \<longrightarrow> B \<in> good \<longrightarrow> 
     Key K \<in> analz (IK s) \<longrightarrow>
       (K, A, B, Ra$na, Ts) \<in> leak s
  }"

lemmas m3_inv3_ikk_initI = m3_inv3_ikk_init_def [THEN setc_def_to_intro, rule_format]
lemmas m3_inv3_ikk_initE [elim] = m3_inv3_ikk_init_def [THEN setc_def_to_elim, rule_format]
lemmas m3_inv3_ikk_initD = m3_inv3_ikk_init_def [THEN setc_def_to_dest, rule_format, rotated 1]

lemma PO_m3_inv3_ikk_init: "reach m3 \<subseteq> m3_inv3_ikk_init"
proof (rule INV_from_Refinement_using_invariants [OF m3_refines_m2])
  show "Range (R23 \<inter> 
          m2_inv3a_sesK_compr 
          \<times> (m3_inv7a_sesK_compr \<inter> m3_inv7b_sesK_compr_non \<inter> m3_inv6_ticket \<inter> m3_inv4_lkeysec) 
        \<inter> m2_inv6_ikk_init \<times> UNIV) 
      \<subseteq> m3_inv3_ikk_init"
    by (auto simp add: R23_def R23_pres_def intro!: m3_inv3_ikk_initI) 
       (elim m2_inv6_ikk_initE, auto dest: R23_keys_dests) 
qed auto    


subsubsection {* inv4 (derived): Key secrecy for responder *}
(*invh*************************************************************************)

definition 
  m3_inv4_ikk_resp :: "m3_state set"
where
  "m3_inv4_ikk_resp \<equiv> {s. \<forall>A B Rb K Ts nl.
     runs s Rb = Some (Resp, [A, B], aKey K # aNum Ts # nl) \<longrightarrow> A \<in> good \<longrightarrow> B \<in> good \<longrightarrow> 
     Key K \<in> analz (IK s) \<longrightarrow>
       (\<exists>Na. (K, A, B, Na, Ts) \<in> leak s)
  }"

lemmas m3_inv4_ikk_respI = m3_inv4_ikk_resp_def [THEN setc_def_to_intro, rule_format]
lemmas m3_inv4_ikk_respE [elim] = m3_inv4_ikk_resp_def [THEN setc_def_to_elim, rule_format]
lemmas m3_inv4_ikk_respD = m3_inv4_ikk_resp_def [THEN setc_def_to_dest, rule_format, rotated 1]

lemma PO_m3_inv4_ikk_resp: "reach m3 \<subseteq> m3_inv4_ikk_resp"
proof (rule INV_from_Refinement_using_invariants [OF m3_refines_m2])
  show "Range (R23 \<inter> m2_inv3a_sesK_compr 
                   \<times> (m3_inv7a_sesK_compr \<inter> m3_inv7b_sesK_compr_non \<inter> m3_inv6_ticket \<inter> m3_inv4_lkeysec) 
                   \<inter> m2_inv7_ikk_resp \<times> UNIV)
      \<subseteq> m3_inv4_ikk_resp"
    by (auto simp add: R23_def R23_pres_def intro!: m3_inv4_ikk_respI)
       (elim m2_inv7_ikk_respE, auto dest: R23_keys_dests) 
qed auto 


end
