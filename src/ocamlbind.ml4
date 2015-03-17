open Tactics
open Tacticals
open Refiner
open Tacmach
open Entries
open Declarations
open Declare
open Topconstr
open Constrexpr
open Constrintern

open OcamlbindConstants
open OcamlbindState

(** Use site configuration to determine where OCamlBind
    is installed. *)
let coqlib =
    Filename.concat (Filename.concat (Envars.coqlib ()) "user-contrib") "OCamlBind"

(** Use site configuration to use the right ocaml native compilers. *)
let ocamlopt = Envars.ocamlopt ()

(** Use site configuration to use the right ocaml bytecode compilers. *)
let ocamlc = Envars.ocamlc ()

(** [command s] runs [s] and logs the exit status. *)
let command s =
  let ret = Sys.command s in
  Pp.msg (Pp.str (Printf.sprintf "OCamlBind [%d]: %s\n" ret s))

let cleanup fname =
  command (Printf.sprintf "rm %s" fname)

(** [time l f] runs [f ()] displaying its running time. *)
let time l f =
  let start = System.get_time () in
  let y = f () in
  let stop = System.get_time () in
  Pp.msg_info (Pp.str
                 (Printf.sprintf "Running time of the %s: %f secs\n"
                    l
                    (System.time_difference start stop)));
  y

let solve_remaining_apply_goals =
  Proofview.Goal.nf_enter begin fun gl ->
    try 
      let env = Proofview.Goal.env gl in
      let sigma = Proofview.Goal.sigma gl in
      let concl = Proofview.Goal.concl gl in
      if Typeclasses.is_class_type sigma concl then
        let evd', c' = Typeclasses.resolve_one_typeclass env sigma concl in
    Tacticals.New.tclTHEN
          (Proofview.Unsafe.tclEVARS evd')
          (Proofview.V82.tactic (refine_no_check c'))
    else Proofview.tclUNIT ()
    with Not_found -> Proofview.tclUNIT ()
  end

(* Convert the constr [a] to an S-expression, apply [f] to it and converts the
   resulting S-expression back to a constr. *)
(* TODO: register the type of the function represented by [f] and check *)
(* that the one of [a] and of the goal are compatible. *)
let ocamlbind f a =
  Proofview.Goal.nf_enter begin fun gl ->
    let env = Proofview.Goal.env gl in
    let sigma = Proofview.Goal.sigma gl in
    let t1 = time "apply import" (fun () -> apply (Lazy.force Reifiable.import)) in
    let f = get_fun f in
    let a = time "normalize" (fun () -> Redexpr.cbv_vm env sigma a) in
    let a = time "convert sexpr" (fun () -> sexpr_of_coq_sexpr a) in
    let r = time "apply function" (fun () -> f a) in
    let r = time "mk_sexpr" (fun () -> mk_sexpr r) in
    let t2 = time "apply term" (fun () -> apply r) in
    Tacticals.New.tclTHENLIST [ t1; solve_remaining_apply_goals; t2 ]
  end

(* Convert the constr_expr [c] to an S-expression and apply [f] to it. *)
(* The result is ignored. *)
(* TODO: register the type of the function represented by [f] and check *)
(* that the one of [c] is compatible. *)
let ocamlrun f c =
  let export = Lazy.force Reifiable.export_ref in
  let export = Nametab.path_of_global export in
  let export = Libnames.Qualid(Loc.ghost,Libnames.qualid_of_path export) in
  let export = CRef(export, None) in
  let c = CApp(Loc.ghost, (None,export), [(c,None)]) in
  let env = Global.env () in
  let evd = Evd.from_env env in
  let (c,ctx) = interp_constr env evd c in
  let c = Redexpr.cbv_vm env evd c in
  let c = sexpr_of_coq_sexpr c in
  let f = get_fun f in
  let _ = f c in ()

let _ = register_fun "id" (fun x -> x)

DECLARE PLUGIN "ocamlbindPlugin"

TACTIC EXTEND ocamlbind
  [ "ocamlbind" string(f) constr(a) ] -> [ ocamlbind f a ]
END

VERNAC COMMAND EXTEND OCamlrun CLASSIFIED AS QUERY
  [ "OCamlrun" string(f) constr(a) ] -> [ ocamlrun f a ]
END
