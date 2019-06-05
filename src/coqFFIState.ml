(*open Errors*)
open Printf
open Names
(**open Constr**)
open CoqFFIConstants

let registered_funs = (Hashtbl.create 17 : (string, sexpr -> sexpr) Hashtbl.t)

let register_fun id f = Hashtbl.add registered_funs id f

let get_fun id =
  try Hashtbl.find registered_funs id
  with Not_found -> fun x -> x
    (**Errors.error ("Function \"" ^ id ^ "\" was not registered."); fun x -> x**)

let get_fun_unsafe id =
  try Obj.magic (Hashtbl.find registered_funs id)
  with Not_found -> fun x -> x
    (**Errors.error ("Function \"" ^ id ^ "\" was not registered."); fun x -> x**)
