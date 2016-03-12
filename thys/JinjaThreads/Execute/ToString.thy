(*  Title:      JinjaThreads/Execute/ToString.thy
    Author:     Andreas Lochbihler
*)

section {* String representation of types *}

theory ToString imports
  "../J/Expr"
  "../JVM/JVMInstructions"
  (*"../../Collections/impl/TrieMapImpl"
  "../../Collections/impl/RBTMapImpl"
  "../../Collections/common/Assoc_List"*)
  "../Basic/JT_ICF"
begin

class toString =
  fixes toString :: "'a \<Rightarrow> String.literal"

instantiation bool :: toString begin
definition [code]: "toString b = (case b of True \<Rightarrow> STR ''True'' | False \<Rightarrow> STR ''False'')"
instance proof qed
end

instantiation char :: toString begin
definition [code]: "toString (c :: char) = String.implode [c]"
instance proof qed
end

instantiation String.literal :: toString begin
definition [code]: "toString (s :: String.literal) = s"
instance proof qed
end

fun list_toString :: "String.literal \<Rightarrow> 'a :: toString list \<Rightarrow> String.literal list"
where
  "list_toString sep [] = []"
| "list_toString sep [x] = [toString x]"
| "list_toString sep (x#xs) = toString x # sep # list_toString sep xs"

instantiation list :: (toString) toString begin
definition [code]:
  "toString (xs :: 'a list) = Auxiliary.concat (STR ''['' # list_toString (STR '','') xs @ [STR '']''])"
instance proof qed
end

definition digit_toString :: "int \<Rightarrow> String.literal"
where
  "digit_toString k = (if k = 0 then STR ''0''
    else if k = 1 then STR ''1''
    else if k = 2 then STR ''2''
    else if k = 3 then STR ''3''
    else if k = 4 then STR ''4''
    else if k = 5 then STR ''5''
    else if k = 6 then STR ''6''
    else if k = 7 then STR ''7''
    else if k = 8 then STR ''8''
    else if k = 9 then STR ''9''
    else undefined)"

function int_toString :: "int \<Rightarrow> String.literal list"
where
  "int_toString n = 
  (if n < 0 then STR ''-'' # int_toString (- n)
   else if n < 10 then [digit_toString n ]
   else int_toString (n div 10) @ [digit_toString (n mod 10)])"
by pat_completeness simp
termination by size_change

instantiation int :: toString begin
definition [code]: "toString i = Auxiliary.concat (int_toString i)"
instance proof qed
end

instantiation nat :: toString begin
definition [code]: "toString n = toString (int n)"
instance proof qed
end

instantiation option :: (toString) toString begin
primrec toString_option :: "'a option \<Rightarrow> String.literal" where
  "toString None = STR ''None''"
| "toString (Some a) = Auxiliary.concat [STR ''Some ('', toString a, STR '')'']"
instance proof qed
end

instantiation finfun :: ("{toString, card_UNIV, equal, linorder}", toString) toString begin
definition [code]: 
  "toString (f :: 'a \<Rightarrow>f 'b) = 
   Auxiliary.concat 
     (STR ''('' 
     # toString (finfun_default f) 
     # concat (map (\<lambda>x. [STR '','', toString x, STR ''|->'', toString (f $ x)]) (finfun_to_list f)) 
     @ [STR '')''])"
instance proof qed
end

instantiation word :: (len) toString begin
definition [code]: "toString (w :: 'a word) = toString (sint w)"
instance proof qed
end

instantiation "fun" :: (type, type) toString begin
definition [code]: "toString (f :: 'a \<Rightarrow> 'b) = STR ''fn''"
instance proof qed
end

instantiation val :: (toString) toString begin
fun toString_val :: "('a :: toString) val \<Rightarrow> String.literal"
where
  "toString Unit = STR ''Unit''"
| "toString Null = STR ''Null''"
| "toString (Bool b) = Auxiliary.concat [STR ''Bool '', toString b]"
| "toString (Intg i) = Auxiliary.concat [STR ''Intg '', toString i]"
| "toString (Addr a) = Auxiliary.concat [STR ''Addr '', toString a]"
instance proof qed
end

instantiation ty :: toString begin
primrec toString_ty :: "ty \<Rightarrow> String.literal"
where
  "toString Void = STR ''Void''"
| "toString Boolean = STR ''Boolean''"
| "toString Integer = STR ''Integer''"
| "toString NT = STR ''NT''"
| "toString (Class C) = Auxiliary.concat [STR ''Class '', toString C]"
| "toString (T\<lfloor>\<rceil>) = Auxiliary.concat [toString T, STR ''[]'']"
instance proof qed
end

instantiation bop :: toString begin
primrec toString_bop :: "bop \<Rightarrow> String.literal" where
  "toString Eq = STR ''==''"
| "toString NotEq = STR ''!=''"
| "toString LessThan = STR ''<''"
| "toString LessOrEqual = STR ''<=''"
| "toString GreaterThan = STR ''>''"
| "toString GreaterOrEqual = STR ''>=''"
| "toString Add = STR ''+''"
| "toString Subtract = STR ''-''"
| "toString Mult = STR ''*''"
| "toString Div = STR ''/''"
| "toString Mod = STR ''%''"
| "toString BinAnd = STR ''&''"
| "toString BinOr = STR ''|''"
| "toString BinXor = STR ''^''"
| "toString ShiftLeft = STR ''<<''"
| "toString ShiftRightZeros = STR ''>>''"
| "toString ShiftRightSigned = STR ''>>>''"
instance proof qed
end

instantiation addr_loc :: toString begin
primrec toString_addr_loc :: "addr_loc \<Rightarrow> String.literal" where
  "toString (CField C F) = Auxiliary.concat [STR ''CField '', F, STR ''{'', C, STR ''}'']"
| "toString (ACell n) = Auxiliary.concat [STR ''ACell '', toString n]"
instance proof qed
end

instantiation htype :: toString begin
fun toString_htype :: "htype \<Rightarrow> String.literal" where
  "toString (Class_type C) = C"
| "toString (Array_type T n) = Auxiliary.concat [toString T, STR ''['', toString n, STR '']'']"
instance proof qed
end

instantiation obs_event :: (toString, toString) toString begin
primrec toString_obs_event :: "('a :: toString, 'b :: toString) obs_event \<Rightarrow> String.literal"
where
  "toString (ExternalCall ad M vs v) = 
   Auxiliary.concat [STR ''ExternalCall '', M, STR ''('', toString vs, STR '') = '', toString v]"
| "toString (ReadMem ad al v) =
   Auxiliary.concat [STR ''ReadMem '', toString ad, STR ''@'', toString al, STR ''='', toString v]"
| "toString (WriteMem ad al v) =
   Auxiliary.concat [STR ''WriteMem '', toString ad, STR ''@'', toString al, STR ''='', toString v]"
| "toString (NewHeapElem ad hT) = Auxiliary.concat [STR ''Allocate '', toString ad, STR '':'', toString hT]"
| "toString (ThreadStart t) = Auxiliary.concat [STR ''ThreadStart '', toString t]"
| "toString (ThreadJoin t) = Auxiliary.concat [STR ''ThreadJoin '', toString t]"
| "toString (SyncLock ad) = Auxiliary.concat [STR ''SyncLock '', toString ad]"
| "toString (SyncUnlock ad) = Auxiliary.concat [STR ''SyncUnlock '', toString ad]"
| "toString (ObsInterrupt t) = Auxiliary.concat [STR ''Interrupt '', toString t]"
| "toString (ObsInterrupted t) = Auxiliary.concat [STR ''Interrupted '', toString t]"
instance proof qed
end

instantiation prod :: (toString, toString) toString begin
definition "toString = (\<lambda>(a, b). Auxiliary.concat [STR ''('', toString a, STR '', '', toString b, STR '')''])"
instance proof qed
end

instantiation fmod_ext :: (toString) toString begin
definition "toString fd = Auxiliary.concat [STR ''{|volatile='', toString (volatile fd), STR '', '', toString (fmod.more fd), STR ''|}'']"
instance proof qed
end

instantiation unit :: toString begin
definition "toString (u :: unit) = STR ''()''"
instance proof qed
end

instantiation exp :: (toString, toString, toString) toString begin
fun toString_exp :: "('a :: toString, 'b :: toString, 'c :: toString) exp \<Rightarrow> String.literal"
where
  "toString (new C) = Auxiliary.concat [STR ''new '', C]"
| "toString (newArray T e) = Auxiliary.concat [STR ''new '', toString T, STR ''['', toString e, STR '']'']"
| "toString (Cast T e) = Auxiliary.concat [STR ''('', toString T, STR '') ('', toString e, STR '')'']"
| "toString (InstanceOf e T) = Auxiliary.concat [STR ''('', toString e, STR '') instanceof '', toString T]"
| "toString (Val v) = Auxiliary.concat [STR ''Val ('', toString v, STR '')'']"
| "toString (e1 \<guillemotleft>bop\<guillemotright> e2) = Auxiliary.concat [STR ''('', toString e1, STR '') '', toString bop, STR '' ('', toString e2, STR '')'']"
| "toString (Var V) = Auxiliary.concat [STR ''Var '', toString V]"
| "toString (V := e) = Auxiliary.concat [toString V, STR '' := ('', toString e, STR '')'']"
| "toString (AAcc a i) = Auxiliary.concat [STR ''('', toString a, STR '')['', toString i, STR '']'']"
| "toString (AAss a i e) = Auxiliary.concat [STR ''('', toString a, STR '')['', toString i, STR ''] := ('', toString e, STR '')'']"
| "toString (ALen a) = Auxiliary.concat [STR ''('', toString a, STR '').length'']"
| "toString (FAcc e F D) = Auxiliary.concat [STR ''('', toString e, STR '').'', F, STR ''{'', D, STR ''}'']"
| "toString (FAss e F D e') = Auxiliary.concat [STR ''('', toString e, STR '').'', F, STR ''{'', D, STR ''} := ('', toString e', STR '')'']"
| "toString (Call e M es) = Auxiliary.concat ([STR ''('', toString e, STR '').'', M, STR ''(''] @ map toString es @ [STR '')''])"
| "toString (Block V T vo e) = Auxiliary.concat ([STR ''{'', toString V, STR '':'', toString T] @ (case vo of None \<Rightarrow> [] | Some v \<Rightarrow> [STR ''='', toString v]) @ [STR ''; '', toString e, STR ''}''])"
| "toString (Synchronized V e e') = Auxiliary.concat [STR ''synchronized_'', toString V, STR ''_('', toString e, STR '') {'', toString e', STR ''}'']"
| "toString (InSynchronized V ad e) = Auxiliary.concat [STR ''insynchronized_'', toString V, STR ''_('', toString ad, STR '') {'', toString e, STR ''}'']"
| "toString (e;;e') = Auxiliary.concat [toString e, STR ''; '', toString e']"
| "toString (if (e) e' else e'') = Auxiliary.concat [STR ''if ('', toString e, STR '') { '', toString e', STR '' } else { '', toString e'', STR ''}'']"
| "toString (while (e) e') = Auxiliary.concat [STR ''while ('', toString e, STR '') { '', toString e', STR '' }'']"
| "toString (throw e) = Auxiliary.concat [STR ''throw ('', toString e, STR '')'']"
| "toString (try e catch(C V) e') = Auxiliary.concat [STR ''try { '', toString e, STR '' } catch ('', C, STR '' '', toString V, STR '') { '', toString e', STR '' }'']"
instance proof qed
end

instantiation instr :: (toString) toString begin
primrec toString_instr :: "'a instr \<Rightarrow> String.literal" where
  "toString (Load i) = Auxiliary.concat [STR ''Load ('', toString i, STR '')'']"
| "toString (Store i) = Auxiliary.concat [STR ''Store ('', toString i, STR '')'']"
| "toString (Push v) = Auxiliary.concat [STR ''Push ('', toString v, STR '')'']"
| "toString (New C) = Auxiliary.concat [STR ''New '', toString C]"
| "toString (NewArray T) = Auxiliary.concat [STR ''NewArray '', toString T]"
| "toString ALoad = STR ''ALoad''"
| "toString AStore = STR ''AStore''"
| "toString ALength = STR ''ALength''"
| "toString (Getfield F D) = Auxiliary.concat [STR ''Getfield  '', toString F, STR '' '', toString D]"
| "toString (Putfield F D) = Auxiliary.concat [STR ''Putfield  '', toString F, STR '' '', toString D]"
| "toString (Checkcast T) = Auxiliary.concat [STR ''Checkcast '', toString T]"
| "toString (Instanceof T) = Auxiliary.concat [STR ''Instanceof '', toString T]"
| "toString (Invoke M n) =  Auxiliary.concat [STR ''Invoke '', toString M, STR '' '', toString n]"
| "toString Return = STR ''Return''"
| "toString Pop = STR ''Pop''"
| "toString Dup = STR ''Dup''"
| "toString Swap = STR ''Swap''"
| "toString (BinOpInstr bop) = Auxiliary.concat [STR ''BinOpInstr  '', toString bop]"
| "toString (Goto i) = Auxiliary.concat [STR ''Goto '', toString i]"
| "toString (IfFalse i) = Auxiliary.concat [STR ''IfFalse '', toString i]"
| "toString ThrowExc = STR ''ThrowExc''"
| "toString MEnter = STR ''monitorenter''"
| "toString MExit = STR ''monitorexit''"
instance proof qed
end

instantiation trie :: (toString, toString) toString begin
definition [code]: "toString (t :: ('a, 'b) trie) = toString (tm_to_list t)"
instance proof qed
end

instantiation rbt :: ("{toString,linorder}", toString) toString begin
definition [code]: 
  "toString (t :: ('a, 'b) rbt) = 
   Auxiliary.concat (list_toString (STR [CHAR 0x2C, CHAR 0x0A]) (rm_to_list t))"
instance proof qed
end

instantiation assoc_list :: (toString, toString) toString begin
definition [code]: "toString = toString \<circ> Assoc_List.impl_of"
instance proof qed
end

code_printing
  class_instance String.literal :: toString \<rightharpoonup> (Haskell) -

end
