open Format
open Syntax
open Support.Error
open Support.Pervasive

(* ------------------------   EVALUATION  ------------------------ *)
(*Note: TmMkpair(_,_,_) is the tree node of "pair _ _" while TmPair(_,_,_) is it's normal form*)

let rec isval ctx t = match t with
    TmTrue(_)  -> true
  | TmFalse(_) -> true
  | TmAbs(_,_,_,_) -> true
  | TmUnit(_) -> true
  | TmPair(_,_,_) -> true
  | _ -> false

exception NoRuleApplies

let rec eval1 ctx t = match t with
    TmApp(fi,TmAbs(_,x,tyT11,t12),v2) when isval ctx v2 ->
      termSubstTop v2 t12
  | TmApp(fi,v1,t2) when isval ctx v1 ->
      let t2' = eval1 ctx t2 in
      TmApp(fi, v1, t2')
  | TmApp(fi,t1,t2) ->
      let t1' = eval1 ctx t1 in
      TmApp(fi, t1', t2)
  | TmIf(_,TmTrue(_),t2,t3) ->
      t2
  | TmIf(_,TmFalse(_),t2,t3) ->
      t3
  | TmIf(fi,t1,t2,t3) ->
      let t1' = eval1 ctx t1 in
      TmIf(fi, t1', t2, t3)
  | TmLet(fi,x,v1,t2) when isval ctx v1 ->
      termSubstTop v1 t2
  | TmLet(fi,x,t1,t2) ->
      let t1' = eval1 ctx t1 in
      TmLet(fi,x,t1',t2)
  | TmMkpair(fi,v1,v2) when (isval ctx v1) & (isval ctx v2) -> 
      TmPair(fi,v1,v2)
  | TmMkpair(fi,v1,t2) when isval ctx v1 -> 
      let t2' = eval1 ctx t2 in
      TmMkpair(fi,v1,t2')
  | TmMkpair(fi,t1,t2) ->
      let t1'= eval1 ctx t1 in
      TmMkpair(fi,t1',t2)
  | TmFst(fi,vp1) when isval ctx vp1->
      (match vp1 with 
	TmPair(fi,v1,v2) -> v1
	| _ -> raise NoRuleApplies )
  | TmFst(fi,t1) ->
	let t1' = eval1 ctx t1 in
        TmFst(fi,t1')    
  | TmSnd(fi,vp1) when isval ctx vp1->
      (match vp1 with 
	TmPair(fi,v1,v2) -> v2
	| _ -> raise NoRuleApplies )
  | TmSnd(fi,t1) ->
	let t1' = eval1 ctx t1 in
        TmSnd(fi,t1')    
  | _ -> 
      raise NoRuleApplies

let rec eval ctx t =
  try let t' = eval1 ctx t
      in eval ctx t'
  with NoRuleApplies -> t

(* ------------------------   TYPING  ------------------------ *)
(*Note: TyCp is the type of a pair i.e. type x type*)

let rec typeof ctx t =
  match t with
    TmVar(fi,i,_) -> getTypeFromContext fi ctx i
  | TmAbs(fi,x,tyT1,t2) ->
      let ctx' = addbinding ctx x (VarBind(tyT1)) in
      let tyT2 = typeof ctx' t2 in
      TyArr(tyT1, tyT2)
  | TmApp(fi,t1,t2) ->
      let tyT1 = typeof ctx t1 in
      let tyT2 = typeof ctx t2 in
      (match tyT1 with
          TyArr(tyT11,tyT12) ->
            if (=) tyT2 tyT11 then tyT12
            else error fi "parameter type mismatch"
        | _ -> error fi "arrow type expected")
  | TmTrue(fi) -> 
      TyBool
  | TmFalse(fi) -> 
      TyBool
  | TmUnit(fi) -> 
      TyUnit
  | TmPair(fi,t1,t2) ->
	TyCp(typeof ctx t1,typeof ctx t2)
  | TmLet(fi,x,t1,t2) ->
     let tyT1 = typeof ctx t1  in
     let ctx' = addbinding ctx x (VarBind(tyT1)) in
     (typeof ctx' t2)
  | TmMkpair(fi,t1,t2) ->
     let tyT1 = typeof ctx t1 in
     if (=) tyT1 (typeof ctx t2) then TyCp(tyT1,tyT1)
     else error fi "Type mismatch in pair"    
  | TmFst(fi,t1) ->
     let tyT1 = typeof ctx t1 in
     (match tyT1 with 
	TyCp(tyT11,tyT12) -> tyT11
	| _ -> error fi "Bad argument for fst")
  | TmSnd(fi,t1) ->
     let tyT1 = typeof ctx t1 in
     (match tyT1 with 
	TyCp(tyT11,tyT12) -> tyT12
	| _ -> error fi "Bad argument for snd")
  | TmIf(fi,t1,t2,t3) ->
     if (=) (typeof ctx t1) TyBool then
       let tyT2 = typeof ctx t2 in
       if (=) tyT2 (typeof ctx t3) then tyT2
       else error fi "arms of conditional have different types"
     else error fi "guard of conditional not a boolean" 
