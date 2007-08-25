(* Ocsigen
 * http://www.ocsigen.org
 * Module eliom.ml
 * Copyright (C) 2007 Vincent Balat
 * Laboratoire PPS - CNRS Université Paris Diderot
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, with linking exception; 
 * either version 2.1 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *)

open Http_frame
open Http_com
open Lwt
open Ocsimisc
open Extensions
open Eliommod
open Lazy

exception Eliom_Link_too_old = Eliommod.Eliom_Link_too_old
exception Eliom_Session_expired = Eliommod.Eliom_Session_expired
exception Eliom_Wrong_parameter = Eliommod.Eliom_Wrong_parameter
exception Eliom_Typing_Error = Eliommod.Eliom_Typing_Error

let _ = Random.self_init ()

let get_config () = 
  match global_register_allowed () with
  | Some _ -> !Eliommod.config
  | None -> raise (Eliom_function_forbidden_outside_site_loading "get_config")

type current_url = Extensions.current_url
type url_path = Extensions.url_path
type server_params = Eliommod.server_params

let string_of_url_path = string_of_url_path

let get_user_agent ~sp:(ri,_,_) = ri.ri_user_agent
let get_full_url ~sp:(ri,_,_) = ri.ri_url_string
let get_ip ~sp:(ri,_,_) = ri.ri_ip
let get_inet_addr ~sp:(ri,_,_) = ri.ri_inet_addr
let get_get_params ~sp:(ri,_,_) = force ri.ri_get_params
let get_all_get_params ~sp:(_,si,_) = si.si_all_get_params
let get_get_params_string ~sp:(ri,_,_) = ri.ri_get_params_string
let get_post_params ~sp:(ri,_,_) = force ri.ri_post_params
let get_all_post_params ~sp:(_,si,_) = si.si_all_post_params
let get_current_path_string ~sp:(ri,_,_) = ri.ri_path_string
let get_current_path ~sp:(ri,_,_) = ri.ri_path
let get_hostname ~sp:(ri,_,_) = ri.ri_host
let get_port ~sp:(ri,_,_) = ri.ri_port
let get_other_get_params ~sp:(_,si,_) = si.si_other_get_params
let get_suffix ~sp:(_,_,(_,_,_,_,s)) = s
let get_exn ~sp:(_,si,_) = si.si_exn
let get_config_file_charset ~sp:(_,si,_) = si.si_config_file_charset
let get_cookies ~sp:(ri,_,_) = force ri.ri_cookies
let get_cookie ~sp:(_,si,_) = !(si.si_cookie)
let get_persistent_cookie ~sp:(_,si,_) = !(si.si_persistent_cookie)

let get_default_timeout = Eliommod.get_default_timeout
let set_global_timeout ?sp s = 
  match sp with
  | Some (_, _, (working_dir, _, _, _, _)) ->
      Eliommod.set_global_timeout working_dir s
  | None ->
      match global_register_allowed () with
      | Some get_current_hostdir ->
          Eliommod.set_global_timeout (snd (get_current_hostdir ())) s
      | _ -> raise (Eliom_function_forbidden_outside_site_loading 
                      "set_global_timeout")

let get_global_timeout ?sp () = 
  match sp with
  | Some (_, _, (working_dir, _, _, _, _)) ->
      Eliommod.find_global_timeout working_dir
  | None ->
      match global_register_allowed () with
      | Some get_current_hostdir ->
          Eliommod.find_global_timeout (snd (get_current_hostdir ()))
      | _ -> raise (Eliom_function_forbidden_outside_site_loading
                      "get_global_timeout")

let get_default_persistent_timeout = Eliommod.get_default_persistent_timeout

let set_global_persistent_timeout ?sp s = 
  match sp with
  | Some (_, _, (working_dir, _, _, _, _)) ->
      Eliommod.set_global_persistent_timeout working_dir s
  | None ->
      match global_register_allowed () with
      | Some get_current_hostdir ->
          Eliommod.set_global_persistent_timeout
            (snd (get_current_hostdir ())) s
      | _ -> raise (Eliom_function_forbidden_outside_site_loading
                      "set_global_persistent_timeout")

let get_global_persistent_timeout ?sp () =
  match sp with
  | Some (_, _, (working_dir, _, _, _, _)) ->
      Eliommod.find_global_persistent_timeout working_dir
  | None ->
      match global_register_allowed () with
      | Some get_current_hostdir ->
          Eliommod.find_global_persistent_timeout
            (snd (get_current_hostdir ()))
      | _ -> raise (Eliom_function_forbidden_outside_site_loading
                      "get_global_persistent_timeout")


let set_user_timeout ~sp:(_,_,(_,_,_,(tor,_,_,_),_)) t = tor := Some t
let unset_user_timeout ~sp:(_,_,(_,_,_,(tor,_,_,_),_)) = tor := None
let get_user_timeout ~sp:(_,_,(working_dir,_,_,(tor,_,_,_),_)) = 
  match !tor with
  | None -> Eliommod.find_global_timeout working_dir
  | Some t -> t

let set_user_expdate ~sp:(_,_,(_,_,_,(_,exp,_,_),_)) t = exp := t
let get_user_expdate ~sp:(_,_,(working_dir,_,_,(_,exp,_,_),_)) = !exp

let set_user_persistent_timeout ~sp:(_,_,(_,_,_,(_,_,tor,_),_)) t = tor := Some t
let unset_user_persistent_timeout ~sp:(_,_,(_,_,_,(_,_,tor,_),_)) = tor := None
let get_user_persistent_timeout ~sp:(_,_,(working_dir,_,_,(_,_,tor,_),_)) = 
  match !tor with
  | None -> Eliommod.find_global_persistent_timeout working_dir
  | Some t -> t

let set_user_persistent_expdate ~sp:(_,_,(_,_,_,(_,_,_,exp),_)) t = exp := t
let get_user_persistent_expdate ~sp:(_,_,(working_dir,_,_,(_,_,_,exp),_)) = !exp

let get_tmp_filename fi = fi.tmp_filename
let get_filesize fi = fi.filesize
let get_original_filename fi = fi.original_filename

let set_exn_handler ?sp h = 
  match sp with
  | Some (_, _, (working_dir, _, _, _, _)) ->
      set_site_handler working_dir h
  | None ->
      match global_register_allowed () with
      | Some get_current_hostdir ->
          set_site_handler (snd (get_current_hostdir ())) h
      | _ -> raise (Eliom_function_forbidden_outside_site_loading
                      "set_site_handler")


let sync f sp g p = Lwt.return (f sp g p)
    
let counter = let c = ref (Random.int 1000000) in fun () -> c := !c + 1 ; !c

let new_state =
  let c : internal_state ref = ref (Random.int 1000000) in
  fun () -> c := !c + 1 ; Some !c


(** Type of names in a formular *)
type 'a param_name = string

type ('a,'b) binsum = Inj1 of 'a | Inj2 of 'b;;

type 'an listnames = 
    {it:'el 'a. ('an -> 'el -> 'a list) -> 'el list -> 'a list -> 'a list}

type coordinates =
    {abscissa: int;
     ordinate: int}

type 'a setoneopt = [ `Set of 'a | `One of 'a | `Opt of 'a ]
type 'a oneopt = [ `One of 'a | `Opt of 'a ]
type 'a setone = [ `Set of 'a | `One of 'a ]

(*****************************************************************************)
(* This is a generalized algebraic datatype *)
(* Use only with constructors from eliom.ml *)
type ('a,+'tipo,+'names) params_type =
    (* 'tipo is [`WithSuffix] or [`WithoutSuffix] *)
  | TProd of (* 'a1 *) ('a,'tipo,'names) params_type * (* 'a2 *) ('a,'tipo,'names) params_type (* 'a = 'a1 * 'a2 ; 'names = 'names1 * 'names2 *)
  | TOption of (* 'a1 *) ('a,'tipo,'names) params_type (* 'a = 'a1 option *)
  | TList of string * (* 'a1 *) ('a,'tipo,'names) params_type (* 'a = 'a1 list *)
  | TSet of ('a,'tipo,'names) params_type (* 'a = 'a1 list *)
  | TSum of (* 'a1 *) ('a,'tipo,'names) params_type * (* 'a2 *) ('a,'tipo,'names) params_type (* 'a = ('a1, 'a2) binsum *)
  | TString of string (* 'a = string *)
  | TInt of string (* 'a = int *)
  | TFloat of string (* 'a = float *)
  | TBool of string (* 'a = bool *)
  | TFile of string (* 'a = file_info *)
  | TUserType of string * (string -> 'a) * ('a -> string) (* 'a = 'a *)
  | TCoord of string (* 'a = 'a1 *)
  | TCoordv of ('a,'tipo,'names) params_type * string
  | TESuffix of string (* 'a = string list *)
  | TESuffixs of string (* 'a = string *)
  | TESuffixu of (string * (string -> 'a) * ('a -> string)) (* 'a = 'a *)
  | TSuffix of ('a,'tipo,'names) params_type (* 'a = 'a1 *)
  | TUnit (* 'a = unit *)
  | TAny (* 'a = (string * string) list *)
;;

type anon_params_type = int

let anonymise_params_type (t : ('a,'b,'c) params_type) : anon_params_type = 
  Hashtbl.hash_param 1000 1000 t


(* As GADT are not implemented in OCaml for the while, we define our own
   constructors for params_type *)
let int (n : string) : (int, [`WithoutSuffix], [ `One of int ] param_name) params_type = 
  TInt n

let float (n : string)
    : (float, [`WithoutSuffix], [ `One of float ] param_name) params_type = 
  TFloat n

let bool (n : string)
    : (bool, [`WithoutSuffix], [ `One of bool ] param_name) params_type
    = TBool n

let string (n : string)
    : (string, [`WithoutSuffix], [ `One of string ] param_name) params_type = 
  TString n

let file (n : string)
    : (file_info , [`WithoutSuffix], [ `One of file_info ] param_name) params_type = 
  TFile n

let radio_answer (n : string)
    : (string option, [`WithoutSuffix], [ `Opt of string ] param_name) params_type =
  TOption (TString n)

let unit : (unit, [`WithoutSuffix], unit) params_type = TUnit

let user_type
    (of_string : string -> 'a) (to_string : 'a -> string) (n : string)
    : ('a,[`WithoutSuffix], [ `One of 'a ] param_name) params_type =
  Obj.magic (TUserType (n, of_string, to_string))

let sum (t1 : ('a,[`WithoutSuffix], 'an) params_type) 
    (t2 : ('b,[`WithoutSuffix], 'bn) params_type) 
    : (('a,'b) binsum, [`WithoutSuffix], 'an * 'bn ) params_type =
  Obj.magic (TSum (t1, t2))

let prod (t1 : ('a,[`WithoutSuffix], 'an) params_type) 
    (t2 : ('b,[<`WithoutSuffix|`Endsuffix], 'bn) params_type)
    : (('a * 'b),[`WithoutSuffix], 'an * 'bn) params_type =
  Obj.magic (TProd ((Obj.magic t1), (Obj.magic t2)))

let ( ** ) = prod

let coordinates (n : string)
    : (coordinates, [`WithoutSuffix], [ `One of coordinates ] param_name) params_type = 
  TCoord n

let string_coordinates (n : string)
    : (string * coordinates,
       [`WithoutSuffix], 
       [ `One of (string * coordinates) ] param_name) params_type = 
  Obj.magic (TCoordv (string n, n))

let int_coordinates (n : string)
    : (int * coordinates,
       [`WithoutSuffix], 
       [ `One of (int * coordinates) ] param_name) params_type = 
  Obj.magic (TCoordv (int n, n))

let float_coordinates (n : string)
    : (float * coordinates,
       [`WithoutSuffix], 
       [ `One of (float * coordinates) ] param_name) params_type = 
  Obj.magic (TCoordv (float n, n))

let user_type_coordinates
    (of_string : string -> 'a) (to_string : 'a -> string) (n : string)
    : ('a * coordinates,
       [`WithoutSuffix], 
       [ `One of ('a * coordinates) ] param_name) params_type = 
  Obj.magic (TCoordv (user_type of_string to_string n, n))

let opt (t : ('a, [`WithoutSuffix], [ `One of 'an ] param_name) params_type) 
    : ('a option,[`WithoutSuffix], [ `Opt of 'an ] param_name) params_type = 
  Obj.magic (TOption t)

let list (n : string) (t : ('a, [`WithoutSuffix], 'an) params_type) 
    : ('a list,[`WithoutSuffix], 'an listnames) params_type = 
  Obj.magic (TList (n,t))

let set (t : string -> ('a, [`WithoutSuffix], [ `One of 'an ] param_name) params_type) (n : string)
    : ('a list, [`WithoutSuffix], [ `Set of 'an ] param_name) params_type = 
  Obj.magic (TSet (t n))

let any
    : ((string * string) list, [`WithoutSuffix], unit) params_type = 
  TAny

let user_dir_regexp = Netstring_pcre.regexp "(.*)\\$u\\(([^\\)]*)\\)(.*)"
let regexp reg dest n = 
  user_type
    (fun s -> 
      match Netstring_pcre.string_match reg s 0 with
      | Some _ -> 
          begin
            (* hack to get user dirs (same as in staticmod) *)
            let s = Netstring_pcre.global_replace reg dest s in
            match Netstring_pcre.string_match user_dir_regexp dest 0 with
            | None -> s
            | Some result -> 
                let user = Netstring_pcre.matched_group result 2 s in
                try
                  let userdir = (Unix.getpwnam user).Unix.pw_dir in
                  (Netstring_pcre.matched_group result 1 s)^
                  userdir^
                  (Netstring_pcre.matched_group result 3 s)
                with _ -> raise Not_found
          end
      | _ -> raise (Failure "Not matching regexp"))
    (fun s -> s)
    n

let all_suffix (n : string) : 
    (string list , [`Endsuffix], 
     [ `One of string list ] param_name) params_type = 
  (Obj.magic (TESuffix n))

let all_suffix_string (n : string) : 
    (string, [`Endsuffix], [ `One of string ] param_name) params_type = 
  (Obj.magic (TESuffixs n))

let all_suffix_user
    (of_string : string -> 'a) (from_string : 'a -> string) (n : string) :
    ('a, [`Endsuffix], [ `One of 'a ] param_name) params_type = 
  (Obj.magic (TESuffixu (n, of_string, from_string)))

let all_suffix_regexp reg dest (n : string) : 
    (string, [`Endsuffix], [ `One of string ] param_name) params_type = 
  all_suffix_user
    (fun s -> 
      match Netstring_pcre.string_match reg s 0 with
      | Some _ -> Netstring_pcre.global_replace reg dest s
      | _ -> raise (Failure "Not matching regexp"))
    (fun s -> s)
    n

let suffix (s : ('s, [<`WithoutSuffix|`Endsuffix], 'sn) params_type) : 
    ('s , [`WithSuffix], 'sn) params_type = 
  (Obj.magic (TSuffix s))

let suffix_prod (s : ('s, [<`WithoutSuffix|`Endsuffix], 'sn) params_type)
    (t : ('a, [`WithoutSuffix], 'an) params_type) : 
    (('s * 'a), [`WithSuffix], 'sn * 'an) params_type = 
  (Obj.magic (TProd (Obj.magic (TSuffix s), Obj.magic t)))

let contains_suffix = function
  | TProd((TSuffix _),_)
  | TSuffix _ -> true
  | _ -> false


(******)
let make_list_suffix i = "["^(string_of_int i)^"]"

let add_to_string s1 sep = function
  | "" -> s1
  | s2 -> s1^sep^s2

let concat_strings s1 sep s2 = match s1,s2 with
| _,"" -> s1
| "",_ -> s2
| _ -> s1^sep^s2

(* The following function reconstructs the value of parameters
   from expected type and GET or POST parameters *)
type 'a res_reconstr_param = 
  | Res_ of ('a * 
               (string * string) list * 
               (string * file_info) list)
  | Errors_ of ((string * exn) list *
                  (string * string) list * 
                  (string * file_info) list)

let reconstruct_params
    (typ : ('a,[<`WithSuffix|`WithoutSuffix],'b) params_type)
    params files urlsuffix : 'a = 
  let rec aux_list t params files name pref suff =
    let rec aa i lp fl pref suff =
      let rec end_of_list len = function
        | [] -> true
        | (a,_)::_ when 
            (try (String.sub a 0 len) = pref
            with _ -> false) -> false
        | _::l -> end_of_list len l
      in
      if end_of_list (String.length pref) lp
      then Res_ ((Obj.magic []), lp, fl)
      else
        try 
          match aux t lp fl pref (suff^(make_list_suffix i)) with
          | Res_ (v,lp2,f) ->
              (match aa (i+1) lp2 f pref suff with
              | Res_ (v2,lp3,f2) -> Res_ ((Obj.magic (v::v2)),lp3,f2)
              | err -> err)
          | Errors_ (errs, l, f) ->
              (match aa (i+1) l f pref suff with
              | Res_ (_,ll,ff) -> Errors_ (errs, ll, ff)
              | Errors_ (errs2, ll, ff) -> Errors_ ((errs@errs2), ll, ff))
        with Not_found -> Res_ ((Obj.magic []), lp, files)
    in 
    aa 0 params files (pref^name^".") suff
  and aux (typ : ('a,[<`WithSuffix|`WithoutSuffix|`Endsuffix],'b) params_type)
      params files pref suff : 'a res_reconstr_param =
    match typ with
    | TProd (t1, t2) ->
        (match aux t1 params files pref suff with
        | Res_ (v1, l1, f) ->
            (match aux t2 l1 f pref suff with
              Res_ (v2, l2, f2) -> Res_ ((Obj.magic (v1, v2)), l2, f2)
            | err -> err)
        | Errors_ (errs, l, f) ->
            (match aux t2 l f pref suff with
              Res_ (_, ll, ff) -> Errors_ (errs, ll, ff)
            | Errors_ (errs2, ll, ff) -> Errors_ ((errs2@errs), ll, ff)))
    | TOption t -> 
        (try 
          (match aux t params files pref suff with
            Res_ (v, l, f) -> Res_ ((Obj.magic (Some v)), l, f)
          | err -> err)
        with Not_found -> Res_ ((Obj.magic None), params, files))
    | TBool name -> 
        (try 
          let v,l = (list_assoc_remove (pref^name^suff) params) in
          Res_ ((Obj.magic true),l,files)
        with Not_found -> Res_ ((Obj.magic false), params, files))
    | TList (n,t) -> Obj.magic (aux_list t params files n pref suff)
    | TSet t -> 
        let rec aux_set params files =
          try
            match aux t params files pref suff with
            | Res_ (vv, ll, ff) -> 
                (match aux_set ll ff with
                | Res_ (vv2, ll2, ff2) -> 
                    Res_ (Obj.magic (vv::vv2), ll2, ff2)
                | err -> err)
            | Errors_ (errs, ll, ff) ->
                (match aux_set ll ff with
                | Res_ (_, ll2, ff2) -> Errors_ (errs, ll2, ff2)
                | Errors_ (errs2, ll2, ff2) -> Errors_ (errs@errs2, ll2, ff2))
          with Not_found -> Res_ (Obj.magic [], params, files)
        in Obj.magic (aux_set params files)
    | TSum (t1, t2) -> 
        (try 
          match aux t1 params files pref suff with
          | Res_ (v,l,files) -> Res_ ((Obj.magic (Inj1 v)),l,files)
          | err -> err
        with Not_found -> 
          (match aux t2 params files pref suff with
          | Res_ (v,l,files) -> Res_ ((Obj.magic (Inj2 v)),l,files)
          | err -> err))
    | TString name -> 
        let v,l = list_assoc_remove (pref^name^suff) params in
        Res_ ((Obj.magic v),l,files)
    | TInt name -> 
        let v,l = (list_assoc_remove (pref^name^suff) params) in 
        (try (Res_ ((Obj.magic (int_of_string v)),l,files))
        with e -> Errors_ ([(pref^name^suff),e], l, files))
    | TFloat name -> 
        let v,l = (list_assoc_remove (pref^name^suff) params) in 
        (try (Res_ ((Obj.magic (float_of_string v)),l,files))
        with e -> Errors_ ([(pref^name^suff),e], l, files))
    | TFile name -> 
        let v,f = list_assoc_remove (pref^name^suff) files in
        Res_ ((Obj.magic v), params, f)
    | TCoord name ->
        let r1 =
          let v, l = (list_assoc_remove (pref^name^suff^".x") params) in
          (try (Res_ ((int_of_string v), l, files))
          with e -> Errors_ ([(pref^name^suff^".x"), e], l, files))
        in
        (match r1 with
        | Res_ (x1, l1, f) ->
            let v, l = (list_assoc_remove (pref^name^suff^".y") l1) in
            (try (Res_ (
                  (Obj.magic
                     {abscissa= x1;
                      ordinate= int_of_string v}), l, f))
            with e -> Errors_ ([(pref^name^suff^".y"), e], l, f))
        | Errors_ (errs, l1, f) ->
            let v, l = (list_assoc_remove (pref^name^suff^".y") l1) in
            (try 
              ignore (int_of_string v); 
              Errors_ (errs, l, f)
            with e -> Errors_ (((pref^name^suff^".y"), e)::errs, l, f)))
    | TCoordv (t, name) ->
        aux (TProd (t, TCoord name)) params files pref suff
    | TUserType (name, of_string, string_of) ->
        let v,l = (list_assoc_remove (pref^name^suff) params) in 
        (try (Res_ ((Obj.magic (of_string v)),l,files))
        with e -> Errors_ ([(pref^name^suff),e], l, files))
    | TUnit -> Res_ ((Obj.magic ()), params, files)
    | TAny -> Res_ ((Obj.magic params), [], files)
    | TESuffix n ->
        let v,l = list_assoc_remove n params in
        (* cannot have prefix or suffix *)
        Res_ ((Obj.magic (Neturl.split_path v)), l, files)
    | TESuffixs n ->
        let v,l = list_assoc_remove n params in
        (* cannot have prefix or suffix *)
        Res_ ((Obj.magic v), l, files)
    | TESuffixu (n, of_string, from_string) ->
        let v,l = list_assoc_remove n params in
        (* cannot have prefix or suffix *)
        Res_ ((Obj.magic (of_string v)), l, files)
    | TSuffix _ -> raise (Ocsigen_Internal_Error "Bad use of suffix")
  in
  let aux2 typ params =
    match Obj.magic (aux typ params files "" "") with
    | Res_ (v,l,files) -> 
        if (l,files) = ([], [])
        then v
        else raise Eliom_Wrong_parameter
    | Errors_ (errs, l, files) -> 
        if (l,files) = ([], [])
        then raise (Eliom_Typing_Error errs)
        else raise Eliom_Wrong_parameter
  in
  let parse_one typ v =
    match typ with
    | TString _ -> Obj.magic v
    | TInt name -> 
        (try Obj.magic (int_of_string v)
        with e -> raise (Eliom_Typing_Error [("<suffix>", e)]))
    | TFloat name -> 
        (try Obj.magic (float_of_string v)
        with e -> raise (Eliom_Typing_Error [("<suffix>", e)]))
    | TUserType (name, of_string, string_of) ->
        (try Obj.magic (of_string v)
        with e -> raise (Eliom_Typing_Error [("<suffix>", e)]))
    | _ -> raise Eliom_Wrong_parameter
  in
  let rec parse_suffix typ suff =
    match (typ, suff) with
    | (TESuffix _), l -> Obj.magic l
    | (TESuffixs _), l -> Obj.magic (string_of_url_path l)
    | (TESuffixu (_, of_string, from_string)), l -> 
        (try
          Obj.magic (of_string (string_of_url_path l))
        with e -> raise (Eliom_Typing_Error [("<suffix>", e)]))
    | _, [a] -> parse_one typ a
    | (TProd (t1, t2)), a::l -> 
        let b = parse_suffix t2 l in (* First we do parse_suffix to detect
                                        wrong number of parameters *)
        Obj.magic ((parse_one t1 a), b)
    | _ -> raise Eliom_Wrong_parameter
  in
  try 
    match typ with
      (* Each suffixed URL has a version with parameters to be used with 
         forms *)
    | TProd((TSuffix s), t) -> 
        if urlsuffix = [""]
          (* no suffix: switching to version with parameters *)
        then 
          (try 
            Obj.magic (aux2 (TProd (s, t)) params)
          with Eliom_Wrong_parameter -> 
            Obj.magic ((parse_suffix s urlsuffix), (aux2 t params)))
        else Obj.magic ((parse_suffix s urlsuffix), (aux2 t params))
    | TSuffix s ->
        if urlsuffix = [""] && params <> [] 
        then
          (try Obj.magic (aux2 s params)
          with Eliom_Wrong_parameter -> 
            Obj.magic (parse_suffix s urlsuffix))
        else Obj.magic (parse_suffix s urlsuffix)
    | _ -> Obj.magic (aux2 typ params)
  with 
  | Not_found -> raise Eliom_Wrong_parameter

(* The following function takes a 'a params_type and a 'a and
   constructs the list of parameters (GET or POST) 
   (This is a marshalling function towards HTTP parameters format) *)
let construct_params_list 
    (typ : ('a, [<`WithSuffix|`WithoutSuffix],'b) params_type)
    (params : 'a) : string list option * (string * string) list =
  let rec aux typ params pref suff l =
    match typ with
      TProd (t1, t2) ->
        let l1 = aux t1 (fst (Obj.magic params)) pref suff l in
        aux t2 (snd (Obj.magic params)) pref suff l1
    | TOption t -> (match ((Obj.magic params) : 'zozo option) with None -> l
      | Some v -> aux t v pref suff l)
    | TBool name -> 
        (if ((Obj.magic params) : bool)
        then ((pref^name^suff), "on")::l
        else l)
    | TList (list_name, t) -> 
        let pref2 = pref^list_name^suff^"." in
        fst 
          (List.fold_left
             (fun (s,i) p -> 
               ((aux t p pref2 (suff^(make_list_suffix i)) s),(i+1)))
             (l,0) (Obj.magic params))
    | TSet t ->
        List.fold_left
          (fun l v -> aux t v pref suff l)
          l
          (Obj.magic params)
    | TSum (t1, t2) -> (match Obj.magic params with
      | Inj1 v -> aux t1 v pref suff l
      | Inj2 v -> aux t2 v pref suff l)
    | TString name -> ((pref^name^suff), (Obj.magic params))::l
    | TInt name -> ((pref^name^suff), (string_of_int (Obj.magic params)))::l
    | TFloat name -> 
        ((pref^name^suff), (string_of_float (Obj.magic params)))::l
    | TFile name -> 
        raise (Failure
                 "Constructing an URL with file parameters not implemented")
    | TUserType (name, of_string, string_of) ->
        ((pref^name^suff), (string_of (Obj.magic params)))::l
    | TCoord name ->
        let coord = Obj.magic params in
        ((pref^name^suff^".x"), string_of_int coord.abscissa)::
        ((pref^name^suff^".y"), string_of_int coord.ordinate)::l
    | TCoordv (t, name) ->
        aux (TProd (t, TCoord name)) params pref suff l
    | TUnit -> l
    | TAny -> l@(Obj.magic params)
    | TESuffix _
    | TESuffixs _
    | TESuffixu _
    | TSuffix _ -> raise (Ocsigen_Internal_Error "Bad use of suffix")
  in
  let rec make_suffix typ params =
    match typ with
    | TProd (t1, t2) ->
        (make_suffix t1 (fst (Obj.magic params)))@
        (make_suffix t2 (snd (Obj.magic params)))
    | TString _ -> [Obj.magic params]
    | TInt _ -> [string_of_int (Obj.magic params)]
    | TFloat _ -> [string_of_float (Obj.magic params)]
    | TUserType (_, of_string, string_of) ->[string_of (Obj.magic params)]
    | TESuffixs _ -> [Obj.magic params]
    | TESuffix _ -> Obj.magic params
    | TESuffixu (_, of_string, string_of) -> [string_of (Obj.magic params)]
    | _ -> raise (Ocsigen_Internal_Error "Bad parameters")
  in
  match typ with
  | TProd((TSuffix s), t) ->
   ((Some (make_suffix s (fst (Obj.magic params)))),
   (aux t (snd (Obj.magic params)) "" "" []))
  | TSuffix s -> (Some (make_suffix s (Obj.magic params))), []
  | _ -> None, (aux typ params "" "" [])


(* contruct the string of parameters (& separated) for GET and POST *)
let construct_params_string = function
  | [] -> ""
  | (a,b)::l -> 
      List.fold_left
        (fun beg (c,d) -> beg^"&"^c^"="^d)
        (a^"="^b)
        l

let construct_params typ p = 
  let suff, pl = construct_params_list typ p in
  (suff, construct_params_string pl)


(* Add a prefix to parameters *)
let rec add_pref_params pref = function
  | TProd (t1, t2) -> TProd ((add_pref_params pref t1),
                             (add_pref_params pref t2))
  | TOption t -> TOption (add_pref_params pref t)
  | TBool name -> TBool (pref^name)
  | TList (list_name, t) -> TList (pref^list_name, t)
  | TSet t -> TSet (add_pref_params pref t)
  | TSum (t1, t2) -> TSum ((add_pref_params pref t1),
                           (add_pref_params pref t2))
  | TString name -> TString (pref^name)
  | TInt name -> TInt (pref^name)
  | TFloat name -> TFloat (pref^name)
  | TFile name -> TFile (pref^name)
  | TUserType (name, of_string, string_of) -> 
      TUserType (pref^name, of_string, string_of)
  | TCoord name -> TCoord (pref^name)
  | TCoordv (t, name) -> TCoordv ((add_pref_params pref t), pref^name)
  | TUnit -> TUnit
  | TAny -> TAny
  | TESuffix n -> TESuffix n
  | TESuffixs n -> TESuffixs n
  | TESuffixu a -> TESuffixu a
  | TSuffix s -> TSuffix s

(* Remove all parameters whose name starts with pref *)
let remove_prefixed_param pref l =
  let len = String.length pref in
  let rec aux = function
    | [] -> []
    | ((n,v) as a)::l -> 
        try if (String.sub n 0 len) = pref 
        then aux l
        else a::(aux l)
        with _ -> a::(aux l)
  in aux l

(*****************************************************************************)
(* Building href *)
let rec string_of_url_path' = function
  | [] -> ""
  | [a] when a = eliom_suffix_internal_name -> ""
  | [a] -> a
  | a::l -> a^"/"^(string_of_url_path' l)

let rec string_of_url_path_suff u = function
  | None -> string_of_url_path' u
  | Some suff -> let deb = (string_of_url_path' u) in
    if deb = "" 
    then string_of_url_path' suff
    else deb^(string_of_url_path' suff)

let reconstruct_absolute_url_path current_url = string_of_url_path_suff

let reconstruct_relative_url_path current_url u suff =
  let rec drop cururl desturl = match cururl, desturl with
  | a::l, [b] -> l, desturl
  | [a], m -> [], m
  | a::l, b::m when a = b -> drop l m
  | a::l, m -> l, m
  | [], m -> [], m
  in let rec makedotdot = function
    | [] -> ""
(*    | [a] -> "" *)
    | _::l -> "../"^(makedotdot l)
  in 
  let aremonter, aaller = drop current_url u
  in let s = (makedotdot aremonter)^(string_of_url_path_suff aaller suff) in
(*  Messages.debug ((string_of_url_path current_url)^"->"^(string_of_url_path u)^"="^s);*)
  if s = "" then defaultpagename else s

let rec relative_url_path_to_myself = function
  | []
  | [""] -> defaultpagename
  | [a] -> a
  | a::l -> relative_url_path_to_myself l
(*****************************************************************************)



(** Typed services *)
type suff = [ `WithSuffix | `WithoutSuffix ]

type servcoserv = [ `Service | `Coservice ]
type getpost = [ `Get | `Post ]
      (* `Post means that there is at least one post param
         (possibly only the state post param).
         `Get is for all the other cases.
       *)
type attached_service_kind = 
    [ `Internal of servcoserv * getpost
    | `External]

type get_attached_service_kind = 
    [ `Internal of servcoserv * [ `Get ]
    | `External ]

type post_attached_service_kind = 
    [ `Internal of servcoserv * [ `Post ]
    | `External ]

type internal = 
    [ `Internal of servcoserv * getpost ]

type registrable = [ `Registrable | `Unregistrable ]

type +'a a_s =
    {url: url_path; (* name of the service without parameters *)
     att_kind: 'a; (* < attached_service_kind *)
     get_state: internal_state option;
     post_state: internal_state option;
   }
      
type +'a na_s =
    {na_name: string option * string option;
     na_kind: 'a; (* < getpost *)
   }

type service_kind =
    [ `Attached of attached_service_kind a_s
  | `Nonattached of getpost na_s ]

type internal_service_kind =
    [ `Attached of internal a_s
  | `Nonattached of getpost na_s ]

type get_service_kind =
    [ `Attached of get_attached_service_kind a_s
  | `Nonattached of [ `Get ] na_s ]

type post_service_kind =
    [ `Attached of post_attached_service_kind a_s
  | `Nonattached of [ `Post ] na_s ]

type attached =
    [ `Attached of attached_service_kind a_s ]

type nonattached =
    [ `Nonattached of getpost na_s ]

type ('get,'post,+'kind,+'tipo,+'getnames,+'postnames,+'registr) service =
    {
     pre_applied_parameters: (string * string) list;
     get_params_type: ('get, 'tipo, 'getnames) params_type;
     post_params_type: ('post, [`WithoutSuffix], 'postnames) params_type;
     max_use: int option; (* Max number of use of this service *)
     timeout: float option; (* Timeout for this service (the service will 
          disappear if it has not been used during this amount of seconds) *)
     kind: 'kind; (* < service_kind *)
   }

let get_or_post = function
  | `Internal (_, `Get) -> Http_frame.Http_header.GET
  | _ -> Http_frame.Http_header.POST
(*  | `External -> POST ? *)


(*****************************************************************************)
(*****************************************************************************)
(* Page registration, handling of links and forms                            *)
(*****************************************************************************)
(*****************************************************************************)

(** Satic directories **)
let static_dir ~sp:(_,_,(curdir,_,_,_,_)) =
    {
     pre_applied_parameters = [];
     get_params_type = suffix (all_suffix eliom_suffix_name);
     post_params_type = unit;
     max_use= None;
     timeout= None;
     kind = `Attached
       {url = curdir@[""];
        get_state = None;
        post_state = None;
        att_kind = `Internal (`Service, `Get);
      }
   }



(****************************************************************************)
(****************************************************************************)

(** Definition of services *)
(** Create a main service (not a coservice) internal or external, get only *)
let new_service_aux_aux
    ~(url : url_path)
    ~kind
    ~get_params
    ~post_params =
(* ici faire une vérification "duplicate parameter" ? *) 
  {
   pre_applied_parameters = [];
   get_params_type = get_params;
   post_params_type = post_params;
   max_use= None;
   timeout= None;
   kind = `Attached
     {url = url;
      att_kind = kind;
      get_state = None;
      post_state = None}
 }
    
let new_service_aux
    ?sp
    ~url
    ~get_params =
  match sp with
  | None ->
      (match global_register_allowed () with
        Some get_current_hostdir ->
          let _,curdir = get_current_hostdir () in
          let full_path = 
            remove_middle_slash (curdir@(change_empty_list url)) in
          let u = new_service_aux_aux
              ~url:full_path
              ~kind:(`Internal (`Service, `Get))
              ~get_params
              ~post_params:unit
          in
          add_unregistered (Some full_path); u
      | None -> raise (Eliom_function_forbidden_outside_site_loading
                         "new_service"))
  | Some (_, _, (curdir, (_, _, _), _, _, _)) ->
      let full_path = 
        remove_middle_slash (curdir@(change_empty_list url)) in
      new_service_aux_aux
        ~url:full_path
        ~kind:(`Internal (`Service, `Get))
        ~get_params
        ~post_params:unit

      
let new_external_service
    ~url
    ~get_params
    ~post_params
    () =
  let suffix = contains_suffix get_params in
  new_service_aux_aux
    ~url:(remove_middle_slash 
            (if suffix then url@[eliom_suffix_internal_name] else url))
    ~kind:`External
    ~get_params 
    ~post_params
    
let new_service
    ?sp
    ~url
    ~get_params
    () =
  let suffix = contains_suffix get_params in
  new_service_aux 
    ?sp
    ~url:(if suffix then url@[eliom_suffix_internal_name] else url)
    ~get_params

let new_naservice_name () = string_of_int (counter ())

let new_coservice
    ?max_use
    ?timeout
    ~fallback
    ~get_params
    () =
  let `Attached k = fallback.kind in
  (* (match global_register_allowed () with
    Some _ -> add_unregistered (Some k.url);
  | _ -> ()); *)
  {fallback with
   max_use= max_use;
   timeout= timeout;
   get_params_type = add_pref_params co_param_prefix get_params;
   kind = `Attached
     {k with
      get_state = new_state ();
      att_kind = `Internal (`Coservice, `Get);
    }
 }
(* Warning: here no GET parameters for the fallback.
   Apply services with apply_service 
   if you want fallbacks with GET parameters *)
    

let new_coservice' ?max_use ?timeout ~get_params () =
  (* match global_register_allowed () with
    Some _ -> add_unregistered None;
  | _ -> () *) (* Do we accept unregistered non-attached coservices? *)
  {
   max_use= max_use;
   timeout= timeout;
   pre_applied_parameters = [];
   get_params_type = add_pref_params na_co_param_prefix get_params;
   post_params_type = unit;
   kind = `Nonattached
     {na_name = (Some (new_naservice_name ()), None);
      na_kind = `Get;
    }
 }
    
    
(****************************************************************************)
(** Register a service with post parameters in the server *)
let new_post_service_aux ~sp ~fallback ~post_params =
(** Create a main service (not a coservice) internal, post only *)
(* ici faire une vérification "duplicate parameter" ? *) 
  let `Attached k1 = fallback.kind in
  let `Internal (k, _) = k1.att_kind in
  {
   pre_applied_parameters = fallback.pre_applied_parameters;
   get_params_type = fallback.get_params_type;
   post_params_type = post_params;
   max_use= None;
   timeout= None;
   kind = `Attached
     {url = k1.url;
      att_kind = `Internal (k, `Post);
      get_state = k1.get_state;
      post_state = None;
    }
 }
    
let new_post_service ?sp ~fallback ~post_params () = 
  (* (if post_params = TUnit
  then Messages.warning "Probably error in the module: \
      Creation of a POST service without POST parameters."); 
      12/07/07
      I remove this warning: POST service without POST parameters means
      that the service will answer to a POST request only.
    *)
  let `Attached k1 = fallback.kind in
  let `Internal (kind, _) = k1.att_kind in
  let url = Some k1.url in
  let u = new_post_service_aux ~sp ~fallback ~post_params in
  match sp with
  | None ->
      (match global_register_allowed () with
        Some _ ->
          add_unregistered url;
          u
      | None ->
          if kind = `Service
          then raise (Eliom_function_forbidden_outside_site_loading
                        "new_post_service")
          else u)
  | _ -> u
(* Warning: strange if post_params = unit... *)    
(* if the fallback is a coservice, do we get a coservice or a service? *)    


let new_post_coservice ?max_use ?timeout ~fallback ~post_params () = 
  let `Attached k1 = fallback.kind in
  (* (match global_register_allowed () with
    Some _ -> add_unregistered (Some k1.url);
  | _ -> ()); *)
  {fallback with 
   post_params_type = post_params;
   max_use= max_use;
   timeout= timeout;
   kind = `Attached 
     {k1 with 
      att_kind = `Internal (`Coservice, `Post);
      post_state = new_state ();
    }
 }
(* It is not possible to make a new_post_coservice function 
   with an optional ?fallback parameter
   because the type 'get of the result depends on the 'get of the
   fallback. Or we must impose 'get = unit ...
 *)

let new_post_coservice' ?max_use ?timeout ~post_params () =
  (* match global_register_allowed () with
    Some _ -> add_unregistered None
  | _ -> () *)
  {
   max_use= max_use;
   timeout= timeout;
   pre_applied_parameters = [];
   get_params_type = unit;
   post_params_type = post_params;
   kind = `Nonattached
     {na_name = (None, Some (new_naservice_name ()));
      na_kind = `Post;
    }
 }

(*
let new_get_post_coservice'
   ?max_use
   ?timeout
    ~fallback
    ~post_params =
  (* match global_register_allowed () with
    Some _ ->
  | _ -> ());
   add_unregistered None; *)
   {
   pre_applied_parameters = fallback.pre_applied_parameters;
   get_params_type = fallback.na_get_params_type;
   post_params_type = post_params;
   max_use= max_use;
   timeout= timeout;
   kind = `Nonattached
   {na_name = (fst fallback.na_name, Some (new_naservice_name ()));
   na_kind = `Internal (`NonAttachedCoservice, `Post);
   }
   }
(* This is a nonattached coservice with GET and POST parameters!
   When reloading, the fallback (a nonattached coservice with only GET 
   parameters) will be called.
 *)

Very experimental
Forms towards that kind of service are not implemented
*)


let preapply ~service getparams =
  let suff, params = construct_params_list service.get_params_type getparams in
  {service with
   pre_applied_parameters = params@service.pre_applied_parameters;
   get_params_type = unit;
   kind = match service.kind with
     `Attached k -> `Attached {k with 
                               url = match suff with
                                 Some suff -> k.url@suff
                               | _ -> k.url}
   | k -> k
 }



(****************************************************************************)

module type REGCREATE = 
  sig

    type page

    val send : 
        ?cookies:cookieslist -> 
          ?charset:string ->
            ?code: int ->
              sp:server_params -> page -> result_to_send

  end


module type FORMCREATE = 
  sig
    type form_content_elt
    type form_content_elt_list
    type form_elt
    type a_content_elt
    type a_content_elt_list
    type a_elt
    type a_elt_list
    type div_content_elt
    type div_content_elt_list
    type uri
    type link_elt
    type script_elt
    type textarea_elt
    type input_elt
    type pcdata_elt
    type select_elt
    type select_content_elt
    type select_content_elt_list
    type option_elt
    type option_elt_list
    type button_elt
    type button_content_elt
    type button_content_elt_list

    type a_attrib_t
    type form_attrib_t
    type input_attrib_t
    type textarea_attrib_t
    type select_attrib_t
    type link_attrib_t
    type script_attrib_t
    type optgroup_attrib_t
    type option_attrib_t
    type button_attrib_t


    type input_type_t
    type button_type_t


        

    val hidden : input_type_t
    val checkbox : input_type_t
    val radio : input_type_t
    val submit : input_type_t
    val file : input_type_t
    val image : input_type_t

    val buttonsubmit : button_type_t

    val empty_seq : form_content_elt_list
    val cons_form : 
        form_content_elt -> form_content_elt_list -> form_content_elt_list 
    val map_option :
        ('a -> option_elt) -> 'a list -> 
          option_elt_list
    val map_optgroup :
        ('a -> select_content_elt) -> 'a -> 'a list -> 
          (select_content_elt * select_content_elt_list)
    val select_content_of_option : option_elt -> select_content_elt

    val make_pcdata : string -> pcdata_elt
    val make_a : ?a:a_attrib_t -> href:string -> a_content_elt_list -> a_elt
    val make_get_form : ?a:form_attrib_t -> 
      action:string -> 
        form_content_elt -> form_content_elt_list -> form_elt
    val make_post_form : ?a:form_attrib_t ->
      action:string -> ?id:string -> ?inline:bool -> 
        form_content_elt -> form_content_elt_list -> form_elt
    val make_hidden_field : input_elt -> form_content_elt
    val remove_first : 
        form_content_elt_list -> form_content_elt * form_content_elt_list
    val make_input : ?a:input_attrib_t -> ?checked:bool ->
      typ:input_type_t -> ?name:string -> ?src:uri ->
        ?value:string -> unit -> input_elt
    val make_button : ?a:button_attrib_t -> button_type:button_type_t ->
      ?name:string -> ?value:string ->
        button_content_elt_list -> button_elt
    val make_textarea : 
        ?a:textarea_attrib_t -> 
          name:string -> ?value:pcdata_elt -> rows:int -> cols:int ->
            unit -> textarea_elt
    val make_select :
        ?a:select_attrib_t ->
          multiple:bool ->
            name:string ->
              select_content_elt ->
                select_content_elt_list ->
                  select_elt
    val make_option : 
        ?a:option_attrib_t ->
          selected:bool ->
            ?value:string ->
              pcdata_elt ->
                option_elt
    val make_optgroup :
        ?a:optgroup_attrib_t ->
          label:string ->
            option_elt ->
              option_elt_list ->
                select_content_elt
    val uri_of_string : string -> uri


    val make_css_link : ?a:link_attrib_t -> uri:uri -> link_elt

    val make_js_script : ?a:script_attrib_t -> uri:uri -> script_elt

  end

module type ELIOMFORMSIG =
(* pasted from mli *)
  sig


    type form_content_elt
    type form_content_elt_list
    type form_elt
    type a_content_elt
    type a_content_elt_list
    type a_elt
    type a_elt_list
    type div_content_elt
    type div_content_elt_list
    type uri
    type link_elt
    type script_elt
    type textarea_elt
    type input_elt
    type pcdata_elt
    type select_elt
    type select_content_elt
    type select_content_elt_list
    type button_elt
    type button_content_elt
    type button_content_elt_list
          
    type a_attrib_t
    type form_attrib_t
    type input_attrib_t
    type textarea_attrib_t
    type select_attrib_t
    type link_attrib_t
    type script_attrib_t
    type optgroup_attrib_t
    type option_attrib_t
    type button_attrib_t

    type input_type_t
    type button_type_t

    val a :
        ?a:a_attrib_t ->
          service:('get, unit, [< get_service_kind ], 
           [< suff ], 'gn, 'pn,
           [< registrable ]) service ->
            sp:server_params -> a_content_elt_list -> 'get -> a_elt
    val get_form :
        ?a:form_attrib_t ->
          service:('get, unit, [< get_service_kind ],
           [<suff ], 'gn, 'pn, 
           [< registrable ]) service ->
             sp:server_params ->
              ('gn -> form_content_elt_list) -> form_elt
    val post_form :
        ?a:form_attrib_t ->
          service:('get, 'post, [< post_service_kind ],
           [< suff ], 'gn, 'pn, 
           [< registrable ]) service ->
            sp:server_params ->
              ('pn -> form_content_elt_list) -> 'get -> form_elt
    val make_uri :
        service:('get, unit, [< get_service_kind ],
         [< suff ], 'gn, 'pn, 
         [< registrable ]) service ->
          sp:server_params -> 'get -> uri

    val js_script :
        ?a:script_attrib_t -> uri:uri -> script_elt
    val css_link : ?a:link_attrib_t -> uri:uri -> link_elt


    val int_input :
        ?a:input_attrib_t -> input_type:input_type_t ->
          ?name:[< int setoneopt ] param_name ->
            ?value:int -> unit -> input_elt
    val float_input :
        ?a:input_attrib_t -> input_type:input_type_t ->
          ?name:[< float setoneopt ] param_name ->
            ?value:float -> unit -> input_elt
    val string_input :
        ?a:input_attrib_t -> input_type:input_type_t ->
           ?name:[< string setoneopt ] param_name -> 
             ?value:string -> unit -> input_elt
    val user_type_input :
        ?a:input_attrib_t -> input_type:input_type_t ->
          ?name:[< 'a setoneopt ] param_name -> 
            ?value:'a -> ('a -> string) -> input_elt
    val any_input :
        ?a:input_attrib_t -> input_type:input_type_t ->
          ?name:string -> ?value:string -> unit -> input_elt

    val file_input :
        ?a:input_attrib_t -> 
          name:[< file_info setoneopt ] param_name -> 
            unit -> input_elt

    val image_input :
        ?a:input_attrib_t -> 
          name:[< coordinates oneopt ] param_name -> 
          ?src:uri -> unit -> input_elt

    val int_image_input :
        ?a:input_attrib_t -> 
          name:[< (int * coordinates) oneopt ] param_name -> value:int -> 
            ?src:uri -> unit -> input_elt
    val float_image_input :
        ?a:input_attrib_t -> 
          name:[< (float * coordinates) oneopt ] param_name -> value:float -> 
            ?src:uri -> unit -> input_elt
    val string_image_input :
        ?a:input_attrib_t -> 
          name:[< (string * coordinates) oneopt ] param_name -> value:string -> 
            ?src:uri -> unit -> input_elt
    val user_type_image_input :
        ?a:input_attrib_t -> 
          name:[< ('a * coordinates) oneopt ] param_name -> value:'a -> 
            ?src:uri -> ('a -> string) -> input_elt
    val any_image_input :
        ?a:input_attrib_t -> 
          name:string -> value:string -> ?src:uri -> unit -> input_elt


    val bool_checkbox :
        ?a:input_attrib_t -> ?checked:bool -> 
          name:[ `One of bool ] param_name -> unit -> input_elt

    val int_checkbox :
        ?a:input_attrib_t -> ?checked:bool -> 
          name:[ `Set of int ] param_name -> value:int -> unit -> input_elt

    val float_checkbox :
        ?a:input_attrib_t -> ?checked:bool -> 
          name:[ `Set of float ] param_name -> value:float -> unit -> input_elt

    val string_checkbox :
        ?a:input_attrib_t -> ?checked:bool -> 
          name:[ `Set of string ] param_name -> value:string -> 
            unit -> input_elt

    val user_type_checkbox :
        ?a:input_attrib_t -> ?checked:bool -> 
          name:[ `Set of 'a ] param_name -> value:'a -> 
            ('a -> string) -> input_elt

    val any_checkbox :
        ?a:input_attrib_t -> ?checked:bool -> 
          name:string -> value:string -> unit -> input_elt


    val string_radio :
        ?a:input_attrib_t -> ?checked:bool -> 
          name:[ `Opt of string ] param_name -> 
            value:string -> unit -> input_elt
    val int_radio :
        ?a:input_attrib_t -> ?checked:bool -> 
           name:[ `Opt of int ] option param_name -> 
             value:int -> unit -> input_elt
    val float_radio :
        ?a:input_attrib_t -> ?checked:bool -> 
           name:[ `Opt of float ] param_name -> 
             value:float -> unit -> input_elt
    val user_type_radio :
        ?a:input_attrib_t -> ?checked:bool ->
           name:[ `Opt of 'a ] param_name -> 
             value:'a -> ('a -> string) -> input_elt
    val any_radio :
        ?a:input_attrib_t -> ?checked:bool -> 
          name:string -> value:string -> unit -> input_elt


    val string_button : 
        ?a:button_attrib_t -> 
          name:[< string setone ] param_name -> value:string -> 
            button_content_elt_list -> button_elt

    val int_button : 
        ?a:button_attrib_t ->
          name:[< int setone ] param_name -> value:int -> 
            button_content_elt_list -> button_elt

    val float_button : 
        ?a:button_attrib_t ->
          name:[< float setone ] param_name -> value:float -> 
            button_content_elt_list -> button_elt

    val user_type_button : 
        ?a:button_attrib_t ->
          name:[< 'a setone ] param_name -> value:'a -> ('a -> string) ->
            button_content_elt_list -> button_elt

    val any_button :
        ?a:button_attrib_t ->
          button_type:button_type_t ->
            name:string -> value:string -> 
              button_content_elt_list -> button_elt

    val button : 
        ?a:button_attrib_t ->
          button_type:button_type_t ->
            button_content_elt_list -> button_elt




    val textarea :
        ?a:textarea_attrib_t ->
          name:[< string setoneopt ] param_name -> ?value:pcdata_elt -> 
            rows:int -> cols:int -> unit -> textarea_elt

    type 'a soption =
        option_attrib_t
          * 'a (* Content (or value if the following is present) *)
          * pcdata_elt option (* if content different from value *)
          * bool (* selected *)

    type 'a select_opt = 
      | Optgroup of 
          optgroup_attrib_t
            * string (* label *)
            * 'a soption
            * 'a soption list
      | Option of 'a soption
            
    val any_select :
        ?a:select_attrib_t ->
          name:string ->
            string select_opt ->
              string select_opt list ->
                select_elt

    val int_select :
        ?a:select_attrib_t ->
          name:[< `Opt of int ] param_name ->
            int select_opt ->
              int select_opt list ->
                select_elt

    val float_select :
        ?a:select_attrib_t ->
          name:[< `Opt of float ] param_name ->
            float select_opt ->
              float select_opt list ->
                select_elt

    val string_select :
        ?a:select_attrib_t ->
          name:[< `Opt of string ] param_name ->
            string select_opt ->
              string select_opt list ->
                select_elt

    val user_type_select :
        ?a:select_attrib_t ->
          name:[< `Opt of 'a ] param_name ->
            'a select_opt ->
              'a select_opt list ->
                ('a -> string) ->
                  select_elt

    val any_multiple_select :
        ?a:select_attrib_t ->
          name:string ->
            string select_opt ->
              string select_opt list ->
                select_elt

    val int_multiple_select :
        ?a:select_attrib_t ->
          name:[< `Set of int ] param_name ->
            int select_opt ->
              int select_opt list ->
                select_elt

    val float_multiple_select :
        ?a:select_attrib_t ->
          name:[< `Set of float ] param_name ->
            float select_opt ->
              float select_opt list ->
                select_elt

    val string_multiple_select :
        ?a:select_attrib_t ->
          name:[< `Set of string ] param_name ->
            string select_opt ->
              string select_opt list ->
                select_elt

    val user_type_multiple_select :
        ?a:select_attrib_t ->
          name:[< `Set of 'a ] param_name ->
            'a select_opt ->
              'a select_opt list ->
                ('a -> string) ->
                  select_elt


  end


module type ELIOMREGSIG1 =
(* pasted from mli *)
  sig


    type page

    val send : 
        ?cookies:cookieslist -> 
          ?charset:string ->
            ?code: int ->
              sp:server_params -> page -> Eliommod.result_to_send

    val register :
        ?sp: server_params ->
        service:('get, 'post,
                 [< internal_service_kind ],
                 [< suff ], 'gn, 'pn, [ `Registrable ]) service ->
        ?error_handler:(server_params ->
                               (string * exn) list -> page Lwt.t) ->
        (server_params -> 'get -> 'post -> page Lwt.t) ->
          unit
(** Register an service in the global table of the server 
   with the associated generation function.
   [register service t f] will associate the service [service] to the function [f].
   [f] is the function that creates a page. 
   It takes three parameters. The first one has type [server_params]
   and allows to have acces to informations about the request.
   The second and third ones are respectively GET and POST parameters.
   For example if [t] is (int "s"), then ['a] is int.

   If you want to register a service in the global table after initialization,
   you must add the [~sp] parameter (current server parameters).
    Warning: registering after initialization is not encouraged for coservices
    without timeout, as such services will be available only until the end
    of the server process!
    If you use that for main services, you will dynamically create new URLs!
    This may be dangerous as they will disappear if you stop the server.
    Be very careful to re-create these URLs when you relaunch the server,
    otherwise, some external links or bookmarks will be broken!

 *)


    val register_for_session :
        sp:server_params ->
          service:('get, 'post, [< internal_service_kind ],
                   [< suff ], 'gn, 'pn, [ `Registrable ]) service ->
              ?error_handler:(server_params -> (string * exn) list -> 
                page Lwt.t) ->
                  (server_params -> 'get -> 'post -> page Lwt.t) -> unit
(** Registers an service and the associated function in the session table.
   If the same client does a request to this service, this function will be
   used instead of the one from the global table.

   Warning:
   - All service must be registered in the global table during initialisation,
   but never after,
   - You (obviously) can't register an service in a session table 
   when no session is active
 *)


    val register_new_service :
        ?sp: server_params ->
        url:url_path ->
            get_params:('get, [< suff ] as 'tipo, 'gn)
              params_type ->
                ?error_handler:(server_params -> (string * exn) list -> 
                  page Lwt.t) ->
                    (server_params -> 'get -> unit -> page Lwt.t) ->
                      ('get, unit, 
                       [> `Attached of 
                         [> `Internal of [> `Service ] * [> `Get] ] a_s ],
                       'tipo, 'gn, unit, 
                       [> `Registrable ]) service
(** Same as [new_service] followed by [register] *)
                      
    val register_new_coservice :
        ?sp: server_params ->
        ?max_use:int ->
        ?timeout:float ->
        fallback:(unit, unit, 
                  [ `Attached of [ `Internal of [ `Service ] * [`Get]] a_s ],
                   [ `WithoutSuffix ] as 'tipo, 
                   unit, unit, [< registrable ])
        service ->
          get_params: 
            ('get, [`WithoutSuffix], 'gn) params_type ->
              ?error_handler:(server_params -> 
                (string * exn) list -> page Lwt.t) ->
                  (server_params -> 'get -> unit -> page Lwt.t) ->
                    ('get, unit, 
                     [> `Attached of 
                       [> `Internal of [> `Coservice ] * [> `Get]] a_s ], 
                     'tipo, 'gn, unit, 
                     [> `Registrable ])
                      service
(** Same as [new_coservice] followed by [register] *)

    val register_new_coservice' :
      ?sp: server_params ->
      ?max_use:int ->
      ?timeout:float ->
        get_params: 
        ('get, [`WithoutSuffix] as 'tipo, 'gn) params_type ->
          ?error_handler:(server_params -> 
            (string * exn) list -> page Lwt.t) ->
              (server_params -> 'get -> unit -> page Lwt.t) ->
                ('get, unit, 
                 [> `Nonattached of [> `Get] na_s ],
                 'tipo, 'gn, unit, [> `Registrable ])
                  service
(** Same as [new_coservice'] followed by [register] *)

    val register_new_coservice_for_session :
        sp:server_params ->
        ?max_use:int ->
        ?timeout:float ->
          fallback:(unit, unit, 
                    [ `Attached of [ `Internal of [ `Service ] * [`Get]] a_s ],
                    [ `WithoutSuffix ] as 'tipo, 
                    unit, unit, [< registrable ])
            service ->
              get_params: 
                ('get, [`WithoutSuffix] as 'tipo, 'gn) params_type ->
                  ?error_handler:(server_params -> (string * exn) list -> 
                    page Lwt.t) ->
                      (server_params -> 'get -> unit -> page Lwt.t) ->
                        ('get, unit, 
                         [> `Attached of 
                           [> `Internal of [> `Coservice ] * [> `Get] ] a_s ], 
                         'tipo, 'gn, unit, 
                         [> `Registrable ])
                          service
(** Same as [new_coservice] followed by [register_for_session] *)

    val register_new_coservice_for_session' :
        sp:server_params ->
        ?max_use:int ->
        ?timeout:float ->
          get_params: 
            ('get, [`WithoutSuffix] as 'tipo, 'gn) params_type ->
              ?error_handler:(server_params -> (string * exn) list -> 
                page Lwt.t) ->
                  (server_params -> 'get -> unit -> page Lwt.t) ->
                    ('get, unit, [> `Nonattached of [> `Get] na_s ], 
                     'tipo, 'gn, unit, 
                     [> `Registrable ])
                      service
(** Same as [new_coservice'] followed by [register_for_session] *)

    val register_new_post_service :
        ?sp: server_params ->
        fallback:('get, unit, 
                  [ `Attached of [ `Internal of 
                    ([ `Service | `Coservice ] as 'kind) * [`Get] ] a_s ],
                  [< suff ] as 'tipo, 'gn,
                  unit, [< `Registrable ])
        service ->
          post_params:('post, [ `WithoutSuffix ], 'pn) params_type ->
            ?error_handler:(server_params -> (string * exn) list -> 
              page Lwt.t) ->
                (server_params -> 'get -> 'post -> page Lwt.t) ->
                  ('get, 'post, [> `Attached of
                    [> `Internal of 'kind * [> `Post] ] a_s ], 
                   'tipo, 'gn, 'pn, [> `Registrable ])
                    service
(** Same as [new_post_service] followed by [register] *)

    val register_new_post_coservice :
        ?sp: server_params ->
        ?max_use:int ->
        ?timeout:float ->
        fallback:('get, unit , 
                  [ `Attached of 
                    [ `Internal of [< `Service | `Coservice ] * [`Get] ] a_s ],
                   [< suff ] as 'tipo, 
                   'gn, unit, [< `Registrable ])
        service ->
          post_params:('post, [ `WithoutSuffix ], 'pn) params_type ->
            ?error_handler:(server_params -> (string * exn) list -> 
              page Lwt.t) ->
                (server_params -> 'get -> 'post -> page Lwt.t) ->
                  ('get, 'post, 
                   [> `Attached of 
                     [> `Internal of [> `Coservice ] * [> `Post] ] a_s ], 
                     'tipo, 'gn, 'pn, [> `Registrable ])
                    service
(** Same as [new_post_coservice] followed by [register] *)

    val register_new_post_coservice' :
        ?sp: server_params ->
        ?max_use:int ->
        ?timeout:float ->
        post_params:('post, [ `WithoutSuffix ], 'pn) params_type ->
          ?error_handler:(server_params -> (string * exn) list -> 
            page Lwt.t) ->
              (server_params -> unit -> 'post -> page Lwt.t) ->
                (unit, 'post, [> `Nonattached of [> `Post] na_s ], 
                 [ `WithoutSuffix ], unit, 'pn,
                 [> `Registrable ])
                  service
(** Same as [new_post_coservice'] followed by [register] *)

(*
    val register_new_get_post_coservice' :
        ?sp: server_params ->
        ?max_use:int ->
        ?timeout:float ->
        fallback:('get, unit , 
                  [ `Nonattached of [`Get] na_s ],
                   [< suff ] as 'tipo, 
                   'gn, unit, [< `Registrable ])
        service ->
          post_params:('post, [ `WithoutSuffix ], 'pn) params_type ->
            ?error_handler:(server_params -> (string * exn) list -> 
              page Lwt.t) ->
                (server_params -> 'get -> 'post -> page Lwt.t) ->
                  ('get, 'post, [> `Nonattached of [> `Post] na_s ], 
                   [> 'tipo], 'gn, 'pn, [> `Registrable ])
                    service
(* * Same as [new_get_post_coservice'] followed by [register] *)
*)

    val register_new_post_coservice_for_session :
        sp:server_params ->
        ?max_use:int ->
        ?timeout:float ->
          fallback:('get, unit, 
                    [< `Attached of [< `Internal of
                      [< `Service | `Coservice ] * [`Get] ] a_s ],
                    [< suff ] as 'tipo, 
                    'gn, unit, [< `Registrable ])
            service ->
              post_params:('post, [ `WithoutSuffix ], 'pn) params_type ->
                ?error_handler:(server_params -> 
                  (string * exn) list -> page Lwt.t) ->
                    (server_params -> 'get -> 'post -> page Lwt.t) ->
                      ('get, 'post, 
                       [> `Attached of 
                         [> `Internal of [> `Coservice ] * [> `Post]] a_s ], 
                       'tipo, 'gn, 'pn, [> `Registrable ])
                        service
(** Same as [new_post_coservice] followed by [register_for_session] *)

    val register_new_post_coservice_for_session' :
        sp:server_params ->
        ?max_use:int ->
        ?timeout:float ->
          post_params:('post, [ `WithoutSuffix ], 'pn) params_type ->
            ?error_handler:(server_params -> 
              (string * exn) list -> page Lwt.t) ->
                (server_params -> unit -> 'post -> page Lwt.t) ->
                  (unit, 'post, [> `Nonattached of [> `Post] na_s ], 
                   [ `WithoutSuffix ], unit, 'pn, 
                   [> `Registrable ])
                    service
(** Same as [new_post_coservice'] followed by [register_for_session] *)

(*
    val register_new_get_post_coservice_for_session' :
        sp:server_params ->
        ?max_use:int ->
        ?timeout:float ->
          fallback:('get, unit, [ `Nonattached of [`Get] na_s ],
                    [< suff ] as 'tipo, 
                    'gn, unit, [< `Registrable ])
            service ->
              post_params:('post, [ `WithoutSuffix ], 'pn) params_type ->
                ?error_handler:(server_params -> 
                  (string * exn) list -> page Lwt.t) ->
                    (server_params -> 'get -> 'post -> page Lwt.t) ->
                      ('get, 'post, [> `NonAttached of [> `Post] na_s ], 
                       'tipo, 'gn, 'pn, [> `Registrable ])
                        service
(* * Same as [new_get_post_coservice] followed by [register_for_session] *)
*)





  end



module type ELIOMREGSIG =
  sig
    include ELIOMREGSIG1
    module Cookies : ELIOMREGSIG1 
    with type page = page * cookieslist
  end




module type ELIOMSIG = sig
  include ELIOMREGSIG
  include ELIOMFORMSIG
end



module MakeRegister = functor
  (Pages : REGCREATE) ->
    (struct

      type page = Pages.page

      let send = Pages.send

      module Cookies = struct
        
        type page = Pages.page * cookieslist
              
        let send ?(cookies=[]) ?charset ?code ~sp (p, cl) =
          Pages.send ~cookies:(cookies@cl) ?charset ?code ~sp p

        let register_aux
            current_dir
            tables
            duringsession (* registering during session? *)
            ~service
            ?(error_handler = fun sp l -> raise (Eliom_Typing_Error l))
            page_generator =
          match service.kind with
          | `Attached attser ->
              let key_kind = get_or_post attser.att_kind in
              add_service
                tables 
	        current_dir
	        duringsession
	        attser.url
                ({key_state = (attser.get_state, attser.post_state);
                  key_kind = key_kind},
                 ((if attser.get_state = None || attser.post_state = None 
                 then (anonymise_params_type service.get_params_type, 
                       anonymise_params_type service.post_params_type)
                 else (0, 0)),
                  (match service.max_use with
                  | None -> None
                  | Some i -> Some (ref i)),
                  (match service.timeout with
                  | None -> None
                  | Some t -> Some (t, ref (t +. Unix.time ()))),
                  (fun ((ri,_,(_,_,_,_,suff)) as sp) -> 
                    (catch (fun () -> 
                      (force ri.ri_post_params) >>=
                      (fun post_params ->
                        (force ri.ri_files) >>=
                        (fun files ->
                          (page_generator sp
                             (reconstruct_params 
                                service.get_params_type
                                (force ri.ri_get_params)
                                []
                                suff)
                             (reconstruct_params
                                service.post_params_type
                                post_params
                                files
                                [])))))
                       (function
                         | Eliom_Typing_Error l -> error_handler sp l
                         | e -> fail e)) >>=
                    (fun (content, cookies_to_set) -> 
                      return (Pages.send 
                                ~cookies:cookies_to_set ~sp content)))))
          | `Nonattached naser ->
              add_naservice 
	        tables
	        current_dir 
	        duringsession
	        naser.na_name
                ((match service.max_use with
                | None -> None
                | Some i -> Some (ref i)),
                 (match service.timeout with
                 | None -> None
                 | Some t -> Some (t, ref (t +. Unix.time ()))),
	         (fun ((ri,_,_) as sp) ->
	           (catch
	              (fun () ->
	                (force ri.ri_post_params) >>=
	                (fun post_params ->
		          (force ri.ri_files) >>=
		          (fun files ->
                            (page_generator sp 
                               (reconstruct_params
                                  service.get_params_type
                                  (force ri.ri_get_params)
                                  []
                                  [])
                               (reconstruct_params
                                  service.post_params_type
                                  post_params
                                  files
                                  [])))))
	              (function
                        | Eliom_Typing_Error l -> error_handler sp l
                        | e -> fail e)) >>=
                   (fun (content, cookies_to_set) -> 
                     return (Pages.send 
                               ~cookies:cookies_to_set ~sp content))))


        let register ?sp ~service ?error_handler page_gen =
          match sp with
          | None ->
              let url =
                match service.kind with
                | `Attached attser -> Some attser.url
                | `Nonattached naser -> None
              in
              (match global_register_allowed () with
              | Some get_current_hostdir ->
                  remove_unregistered url;
                  let (globtables, _, _), curdir = get_current_hostdir () in
                  register_aux 
                    curdir
                    globtables
                    false 
                    ~service ?error_handler page_gen
              | _ -> raise (Eliom_function_forbidden_outside_site_loading
                              "register"))
          | Some (ri, si, (curdir, (globtables, _, _), _, _, _)) ->
              register_aux 
                ?error_handler
                curdir
                globtables
                true
                ~service
                page_gen


(* WARNING: if we create a new service without registering it,
   we can have a link towards a page that does not exist!!! :-(
   That's why I impose to register all service during init.
   The only other way I see to avoid this is to impose a syntax extension
   like "let rec" for service...
 *)



        let register_for_session
            ~sp:(ri, si, (curdir, _, sesstab, _, _))
            ~service
            ?error_handler
            page =
          register_aux
            ?error_handler
            curdir
            !sesstab
            true 
            ~service page



        let register_new_service 
            ?sp
            ~url
            ~get_params
            ?error_handler
            page =
          let u = new_service ?sp ~url ~get_params () in
          register ?sp ~service:u ?error_handler page;
          u
            
        let register_new_coservice
            ?sp
            ?max_use
            ?timeout
            ~fallback
            ~get_params
            ?error_handler
            page =
          let u = new_coservice ?max_use ?timeout ~fallback ~get_params () in
          register ?sp ~service:u ?error_handler page;
          u

        let register_new_coservice'
            ?sp
            ?max_use
            ?timeout
            ~get_params
            ?error_handler
            page =
          let u = new_coservice' ?max_use ?timeout ~get_params () in
          register ?sp ~service:u ?error_handler page;
          u

        let register_new_coservice_for_session
            ~sp
            ?max_use
            ?timeout
            ~fallback
            ~get_params
            ?error_handler
            page =
          let u = new_coservice ?max_use ?timeout ~fallback ~get_params () in
          register_for_session ~sp ~service:u ?error_handler page;
          u

        let register_new_coservice_for_session'
            ~sp
            ?max_use
            ?timeout
            ~get_params
            ?error_handler
            page =
          let u = new_coservice' ?max_use ~get_params () in
          register_for_session ~sp ~service:u ?error_handler page;
          u


        let register_new_post_service 
            ?sp
            ~fallback
            ~post_params
            ?error_handler
            page_gen =
          let u = new_post_service ?sp
              ~fallback:fallback ~post_params:post_params () in
          register ?sp ~service:u ?error_handler page_gen;
          u

        let register_new_post_coservice
            ?sp
            ?max_use
            ?timeout
            ~fallback
            ~post_params
            ?error_handler
            page_gen =
          let u = 
            new_post_coservice ?max_use ?timeout ~fallback ~post_params () in
          register ?sp ~service:u ?error_handler page_gen;
          u

        let register_new_post_coservice'
            ?sp
            ?max_use
            ?timeout
            ~post_params
            ?error_handler
            page_gen =
          let u = new_post_coservice' ?max_use ?timeout ~post_params () in
          register ?sp ~service:u ?error_handler page_gen;
          u

(*
   let register_new_get_post_coservice'
   ?sp
   ?max_use
   ?timeout
   ~fallback
   ~post_params
   ?error_handler
   page_gen =
   let u = new_get_post_coservice'
   ?max_use ?timeout ~fallback ~post_params () in
   register ?sp ~service:u ?error_handler page_gen;
   u
 *)

        let register_new_post_coservice_for_session
            ~sp
            ?max_use
            ?timeout
            ~fallback
            ~post_params
            ?error_handler
            page_gen =
          let u = new_post_coservice 
              ?max_use ?timeout ~fallback ~post_params () in
          register_for_session ~sp ~service:u ?error_handler page_gen;
          u

        let register_new_post_coservice_for_session'
            ~sp
            ?max_use
            ?timeout
            ~post_params
            ?error_handler
            page_gen =
          let u = new_post_coservice' ?max_use ?timeout ~post_params () in
          register_for_session ~sp ~service:u ?error_handler page_gen;
          u

(*
   let register_new_get_post_coservice_for_session'
   ~sp
   ?max_use
   ?timeout
   ~fallback
   ~post_params
   ?error_handler
   page_gen =
   let u = new_get_post_coservice'
   ?max_use ?timeout ~fallback ~post_params () in
   register_for_session ~sp ~service:u ?error_handler page_gen;
   u
 *)


      end


      let make_error_handler ?error_handler () = 
        match error_handler with
          None -> None
        | Some eh -> Some (fun sp l -> eh sp l >>= (fun r -> return (r,[])))

      let register ?sp ~service ?error_handler page_gen =
        Cookies.register
          ?sp
          ~service
          ?error_handler:(make_error_handler ?error_handler ())
          (fun sp g p -> page_gen sp g p >>= (fun r -> return (r,[])))

      let register_for_session
          ~sp
          ~service
          ?error_handler
          page =
        Cookies.register_for_session
          ~sp
          ~service
          ?error_handler:(make_error_handler ?error_handler ())
          (fun sp g p -> page sp g p >>= (fun r -> return (r,[])))

      let register_new_service 
          ?sp
          ~url
          ~get_params
          ?error_handler
          page =
        Cookies.register_new_service 
          ?sp
          ~url
          ~get_params
          ?error_handler:(make_error_handler ?error_handler ())
          (fun sp g p -> page sp g p >>= (fun r -> return (r,[])))
          
      let register_new_coservice
          ?sp
          ?max_use
          ?timeout
          ~fallback
          ~get_params
          ?error_handler
          page =
        Cookies.register_new_coservice
          ?sp
          ?max_use
          ?timeout
          ~fallback
          ~get_params
          ?error_handler:(make_error_handler ?error_handler ())
          (fun sp g p -> page sp g p >>= (fun r -> return (r,[])))

      let register_new_coservice'
          ?sp
          ?max_use
          ?timeout
          ~get_params
          ?error_handler
          page =
        Cookies.register_new_coservice'
          ?sp
          ?max_use
          ?timeout
          ~get_params
          ?error_handler:(make_error_handler ?error_handler ())
          (fun sp g p -> page sp g p >>= (fun r -> return (r,[])))

      let register_new_coservice_for_session
          ~sp
          ?max_use
          ?timeout
          ~fallback
          ~get_params
          ?error_handler
          page =
      Cookies.register_new_coservice_for_session
          ~sp
          ?max_use
          ?timeout
          ~fallback
          ~get_params
          ?error_handler:(make_error_handler ?error_handler ())
          (fun sp g p -> page sp g p >>= (fun r -> return (r,[])))

      let register_new_coservice_for_session'
          ~sp
          ?max_use
          ?timeout
          ~get_params
          ?error_handler
          page =
      Cookies.register_new_coservice_for_session'
          ~sp
          ?max_use
          ?timeout
          ~get_params
          ?error_handler:(make_error_handler ?error_handler ())
          (fun sp g p -> page sp g p >>= (fun r -> return (r,[])))

      let register_new_post_service 
          ?sp
          ~fallback
          ~post_params
          ?error_handler
          page_gen =
      Cookies.register_new_post_service 
          ?sp
          ~fallback
          ~post_params
          ?error_handler:(make_error_handler ?error_handler ())
          (fun sp g p -> page_gen sp g p >>= (fun r -> return (r,[])))

      let register_new_post_coservice
          ?sp
          ?max_use
          ?timeout
          ~fallback
          ~post_params
          ?error_handler
          page_gen =
        Cookies.register_new_post_coservice
          ?sp
          ?max_use
          ?timeout
          ~fallback
          ~post_params
          ?error_handler:(make_error_handler ?error_handler ())
          (fun sp g p -> page_gen sp g p >>= (fun r -> return (r,[])))

      let register_new_post_coservice'
          ?sp
          ?max_use
          ?timeout
          ~post_params
          ?error_handler
          page_gen =
        Cookies.register_new_post_coservice'
          ?sp
          ?max_use
          ?timeout
          ~post_params
          ?error_handler:(make_error_handler ?error_handler ())
          (fun sp g p -> page_gen sp g p >>= (fun r -> return (r,[])))

(*
   let register_new_get_post_coservice'
   ?sp
          ?max_use
          ?timeout
   ~fallback
   ~post_params
   ?error_handler
   page_gen =
   Cookies.register_new_get_post_coservice'
   ?sp
          ?max_use
          ?timeout
   ~fallback
   ~post_params
   ?error_handler:(make_error_handler ?error_handler ())
          (fun sp g p -> page_gen sp g p >>= (fun r -> return (r,[])))

 *)

      let register_new_post_coservice_for_session
          ~sp
          ?max_use
          ?timeout
          ~fallback
          ~post_params
          ?error_handler
          page_gen =
        Cookies.register_new_post_coservice_for_session
          ~sp
          ?max_use
          ?timeout
          ~fallback
          ~post_params
          ?error_handler:(make_error_handler ?error_handler ())
          (fun sp g p -> page_gen sp g p >>= (fun r -> return (r,[])))

      let register_new_post_coservice_for_session'
          ~sp
          ?max_use
          ?timeout
          ~post_params
          ?error_handler
          page_gen =
      Cookies.register_new_post_coservice_for_session'
          ~sp
          ?max_use
          ?timeout
          ~post_params
          ?error_handler:(make_error_handler ?error_handler ())
          (fun sp g p -> page_gen sp g p >>= (fun r -> return (r,[])))

(*
   let register_new_get_post_coservice_for_session'
   sp
          ?max_use
          ?timeout
   ~fallback
   ~post_params
   ?error_handler
   page_gen =
   Cookies.register_new_get_post_coservice_for_session'
   ~sp
          ?max_use
          ?timeout
   ~fallback
   ~post_params
   ?error_handler:(make_error_handler ?error_handler ())
          (fun sp g p -> page_gen sp g p >>= (fun r -> return (r,[])))

 *)


    end : ELIOMREGSIG with 
                 type page = Pages.page)




let make_string_uri
    ~service
    ~sp:((_,si,_) as sp)
    getparams : string =
  match service.kind with
    `Attached attser ->
      begin
        let suff, params_string = 
          construct_params service.get_params_type getparams in
        let preapplied_params = 
          construct_params_string service.pre_applied_parameters in
        let params_string =
          concat_strings preapplied_params "&" params_string in
        let uri = 
          (if attser.att_kind = `External
          then (reconstruct_absolute_url_path
                  (get_current_path sp) attser.url suff)
          else (reconstruct_relative_url_path
                  (get_current_path sp) attser.url suff))
        in
        match attser.get_state with
          None ->
            add_to_string uri "?" params_string
        | Some i -> 
            add_to_string (uri^"?"^
                           get_state_param_name^"="^(string_of_int i))
              "&" params_string
      end
  | `Nonattached naser ->
      let current_get_params =
        List.remove_assoc
          naservice_name
          (remove_prefixed_param na_co_param_prefix (get_all_get_params sp))
      in
      let _, params_string = 
        construct_params service.get_params_type getparams in
      let preapplied_params = 
        construct_params_string service.pre_applied_parameters in
      let params_string =
        concat_strings preapplied_params "&" params_string in
      let naservice_param = 
        match fst naser.na_name with
          Some n -> naservice_name^"="^n
        | _ -> assert false
      in
      let current_get_params_string = 
        construct_params_string current_get_params in
      (("/"^(get_current_path_string sp))^"?"^
       (concat_strings
          current_get_params_string
          "&"
          (naservice_param^"&"^params_string))
      )


module MakeForms = functor
  (Pages : FORMCREATE) ->
    (struct
      
      type form_content_elt = Pages.form_content_elt
      type form_content_elt_list = Pages.form_content_elt_list
      type form_elt = Pages.form_elt
      type a_content_elt = Pages.a_content_elt
      type a_content_elt_list = Pages.a_content_elt_list
      type a_elt = Pages.a_elt
      type a_elt_list = Pages.a_elt_list
      type div_content_elt = Pages.div_content_elt
      type div_content_elt_list = Pages.div_content_elt_list
      type uri = Pages.uri
      type link_elt = Pages.link_elt
      type script_elt = Pages.script_elt
      type textarea_elt = Pages.textarea_elt
      type select_elt = Pages.select_elt
      type input_elt = Pages.input_elt
      type pcdata_elt = Pages.pcdata_elt
      type select_content_elt = Pages.select_content_elt
      type select_content_elt_list = Pages.select_content_elt_list
      type button_elt = Pages.button_elt
      type button_content_elt = Pages.button_content_elt
      type button_content_elt_list = Pages.button_content_elt_list
            
      type a_attrib_t = Pages.a_attrib_t
      type form_attrib_t = Pages.form_attrib_t
      type input_attrib_t = Pages.input_attrib_t
      type textarea_attrib_t = Pages.textarea_attrib_t
      type select_attrib_t = Pages.select_attrib_t
      type link_attrib_t = Pages.link_attrib_t
      type script_attrib_t = Pages.script_attrib_t
      type optgroup_attrib_t = Pages.optgroup_attrib_t
      type option_attrib_t = Pages.option_attrib_t
      type button_attrib_t = Pages.button_attrib_t

      type input_type_t = Pages.input_type_t
      type button_type_t = Pages.button_type_t


(** Functions to construct web pages: *)

      let a ?a
          ~service
          ~sp:((_,si,_) as sp)
          content
          getparams =
        match service.kind with
        | `Attached attser ->
            (let suff, params_string = 
              construct_params service.get_params_type getparams in
            let preapplied_params = 
              construct_params_string service.pre_applied_parameters in
            let params_string =
              concat_strings preapplied_params "&" params_string in
            let uri = 
              (if attser.att_kind = `External
              then 
                (reconstruct_absolute_url_path
                   (get_current_path sp) attser.url suff)
              else 
                (reconstruct_relative_url_path
                   (get_current_path sp) attser.url suff))
            in
            match attser.get_state with
            | None ->
                Pages.make_a 
                  ?a ~href:(add_to_string uri "?" params_string) content
            | Some i -> 
                Pages.make_a ?a
                  ~href:(add_to_string 
                           (uri^"?"^get_state_param_name^"="^(string_of_int i))
                           "&" params_string)
                  content)
        | `Nonattached naser ->
            let current_get_params =
              List.remove_assoc
                naservice_name
                (remove_prefixed_param
                   na_co_param_prefix (get_all_get_params sp))
            in
            let _, params_string = 
              construct_params service.get_params_type getparams in
            let preapplied_params = 
              construct_params_string service.pre_applied_parameters in
            let params_string =
              concat_strings preapplied_params "&" params_string in
            let naservice_param = 
              match fst naser.na_name with
              | Some n -> naservice_name^"="^n
              | _ -> assert false
            in
            let current_get_params_string = 
              construct_params_string current_get_params in
            Pages.make_a ?a
              ~href:(("/"^(get_current_path_string sp))^"?"^
                     (concat_strings
                        current_get_params_string
                        "&"
                        (naservice_param^"&"^params_string))
                    )
              content

      let make_params_names (params : ('t,'tipo,'n) params_type) : 'n =
        let rec aux prefix suffix = function
          | TProd (t1, t2) -> Obj.magic (aux prefix suffix t1, aux prefix suffix t2)
          | TInt name -> Obj.magic (prefix^name^suffix)
          | TFloat name -> Obj.magic (prefix^name^suffix)
          | TString name -> Obj.magic (prefix^name^suffix)
          | TFile name -> Obj.magic (prefix^name^suffix)
          | TUserType (name,o,t) -> Obj.magic (prefix^name^suffix)
          | TCoord name -> Obj.magic (prefix^name^suffix)
          | TCoordv (_, name) -> Obj.magic (prefix^name^suffix)
          | TUnit -> Obj.magic ()
          | TAny -> Obj.magic ()
          | TSet t -> Obj.magic (aux prefix suffix t)
          | TESuffix n -> Obj.magic n
          | TESuffixs n -> Obj.magic n
          | TESuffixu (n,_,_) -> Obj.magic n
          | TSuffix t -> Obj.magic (aux prefix suffix t)
          | TOption t -> Obj.magic (aux prefix suffix t)
          | TBool name -> Obj.magic (prefix^name^suffix)
          | TSum (t1,t2) -> Obj.magic (aux prefix suffix t1, aux prefix suffix t2)
          | TList (name,t1) -> Obj.magic 
                {it =
                 (fun f l endlist ->
                   let length = List.length l in
                   snd
                     (List.fold_right 
                        (fun el (i,l2) -> 
                          let i'= i-1 in
                          (i',(f (aux (prefix^name^".") (make_list_suffix i') t1) el)
                           @l2))
                        l
                        (length,endlist)))}
        in aux "" "" params
          
      let get_form 
          ?a
          ~service
          ~sp:((_,si,_) as sp)
          f =
        match service.kind with
        | `Attached attser ->
            let urlname =
              (if attser.att_kind = `External
              then (reconstruct_absolute_url_path
                      (get_current_path sp) attser.url None)
              else (reconstruct_relative_url_path
                      (get_current_path sp) attser.url None)) in
            let state_param =
              (match attser.get_state with
              | None -> None
              | Some i -> 
                  let i' = string_of_int i in
                  Some (Pages.make_input ~typ:Pages.hidden
                          ~name:get_state_param_name ~value:i' ()))
            in
            let inside = f (make_params_names service.get_params_type) in
            let inside =
              List.fold_left
                (fun s (n,v) -> 
                  Pages.cons_form
                    (Pages.make_hidden_field
	               (Pages.make_input
                          ~typ:Pages.hidden ~name:n ~value:v ()))
                    s
                )
                inside
                service.pre_applied_parameters
            in
            let i1, i =
              match state_param, inside with
              | Some s, i -> (Pages.make_hidden_field s),i
              | None, i -> Pages.remove_first i
            in Pages.make_get_form ?a ~action:urlname i1 i
        | `Nonattached naser ->
            let urlname = "/"^(get_current_path_string sp) in
            let naservice_param_name = naservice_name in
            let naservice_param = 
              match fst naser.na_name with
              | Some n -> n
              | _ -> assert false
            in
            let naservice_line = 
              Pages.make_hidden_field
	        (Pages.make_input
	           ~typ:Pages.hidden 
                   ~name:naservice_param_name
                   ~value:naservice_param ())
            in
            let current_get_params =
              List.remove_assoc
                naservice_name
                (remove_prefixed_param
                   na_co_param_prefix (get_all_get_params sp))
            in
            let inside = f (make_params_names service.get_params_type) in
            let all_lines = 
              List.fold_left
                (fun s (n,v) -> 
                  Pages.cons_form
                    (Pages.make_hidden_field
	               (Pages.make_input
                          ~typ:Pages.hidden ~name:n ~value:v ()))
                    s
                )
                inside
                current_get_params
            in
            let all_lines =
              List.fold_left
                (fun s (n,v) -> 
                  Pages.cons_form
                    (Pages.make_hidden_field
	               (Pages.make_input
                          ~typ:Pages.hidden ~name:n ~value:v ()))
                    s
                )
                all_lines
                service.pre_applied_parameters
            in
            Pages.make_get_form ?a ~action:urlname naservice_line all_lines


      let post_form
          ?a
          ~service
          ~sp
          f 
          getparams =
        match service.kind with
        | `Attached attser ->
            let suff,params_string = 
              construct_params service.get_params_type getparams in
            let preapplied_params = 
              construct_params_string service.pre_applied_parameters in
            let params_string =
              concat_strings preapplied_params "&" params_string in
            let params_string =
              match attser.get_state with
                None -> params_string
              | Some i -> 
                  add_to_string
                    (get_state_param_name^"="^(string_of_int i))
                    "&"
                    params_string
            in
            let urlname = 
              (if attser.att_kind = `External
              then (reconstruct_absolute_url_path
                      (get_current_path sp) attser.url suff)
              else (reconstruct_relative_url_path
                      (get_current_path sp) attser.url suff))
            in
            let state_param =
              (match  attser.post_state with
              | None -> None
              | Some i -> 
                  let i' = string_of_int i in
                  Some (Pages.make_input ~typ:Pages.hidden
                          ~name:post_state_param_name ~value:i' ()))
            in
            let inside = f (make_params_names service.post_params_type) in
            let i1, i =
              match state_param, inside with
              | Some s, i -> (Pages.make_hidden_field s),i
              | None, i -> Pages.remove_first i
            in Pages.make_post_form ?a
              ~action:(add_to_string urlname "?" params_string)
              i1 i
        | `Nonattached naser ->
            (* no GET params here for now *)
            let naservice_param_name = naservice_name in
            let naservice_param = 
              match snd naser.na_name with
                Some n -> n
              | _ -> assert false
            in
            let naservice_line = 
	      Pages.make_input
	        ~typ:Pages.hidden
                ~name:naservice_param_name
                ~value:naservice_param () 
            in
            let v = get_full_url sp in
            let inside = f (make_params_names service.post_params_type) in
            Pages.make_post_form ?a ~action:v
              (Pages.make_hidden_field naservice_line)
              inside

          



      let make_uri ~service ~sp gp =
        Pages.uri_of_string (make_string_uri service sp gp)
                  
          
          
      let js_script = Pages.make_js_script
      let css_link = Pages.make_css_link


      let gen_input ?a ~(input_type : input_type_t) 
          ?value ?src
          ?name (string_of : 'a -> string) =
        (match value with
        | None ->
            Pages.make_input ?a ~typ:input_type ?name ?src ()
        | Some v -> 
            Pages.make_input
              ?a
              ~value:(string_of v)
              ~typ:input_type 
              ?src
              ?name
              ())
          
      let int_input ?a ~input_type
          ?name ?value () = 
        gen_input ?a ~input_type ?value ?name string_of_int
      let float_input ?a ~input_type 
          ?name ?value () =
        gen_input ?a ~input_type ?value ?name string_of_float
      let string_input ?a ~input_type 
          ?name ?value () =
        gen_input ?a ~input_type ?value ?name id
      let user_type_input ?a ~input_type
          ?name ?value string_of = 
        gen_input ?a ~input_type ?value ?name string_of 
      let any_input ?a ~input_type 
          ?name ?value () = 
        gen_input ?a ~input_type ?value ?name id

      let file_input ?a ~name () = 
        Pages.make_input ?a ~typ:Pages.file ~name ()
      (* value attribute not supported by browsers for security reasons *)
      
      let image_input ?a ~name ?src () = 
        Pages.make_input ?a ~typ:Pages.image ~name ?src ()
    (* The behaviour of <input type="image"> without name attribute
       depends on browsers *)
    
      let int_image_input ?a ~name ~value ?src () = 
        gen_input ?a ~input_type:Pages.image ~name
          ~value ?src string_of_int
      let float_image_input ?a ~name ~value ?src () = 
        gen_input ?a ~input_type:Pages.image ~name
          ~value ?src string_of_float
      let string_image_input ?a ~name ~value ?src () = 
        gen_input ?a ~input_type:Pages.image ~name
          ~value ?src id
      let user_type_image_input ?a ~name ~value ?src string_of = 
        gen_input ?a ~input_type:Pages.image ~name
          ~value ?src string_of
      let any_image_input ?a ~(name : string) ~value ?src () = 
        gen_input ?a ~input_type:Pages.image ~name
          ~value ?src id

      let bool_checkbox ?a ?checked ~name () =
        Pages.make_input ?a ?checked ~typ:Pages.checkbox ~name ()

      let int_checkbox ?a ?checked ~name ~value () =
        Pages.make_input ?a ?checked ~typ:Pages.checkbox
          ~name ~value:(string_of_int value) ()

      let float_checkbox ?a ?checked ~name ~value () =
        Pages.make_input ?a ?checked ~typ:Pages.checkbox
          ~name ~value:(string_of_float value) ()

      let string_checkbox ?a ?checked ~name ~value () =
        Pages.make_input ?a ?checked ~typ:Pages.checkbox
          ~name ~value ()

      let user_type_checkbox ?a ?checked ~name ~value string_of =
        Pages.make_input ?a ?checked ~typ:Pages.checkbox
          ~name ~value:(string_of value) ()

      let any_checkbox ?a ?checked ~name ~value () =
        Pages.make_input ?a ?checked ~typ:Pages.checkbox
          ~name ~value ()


      let string_radio ?a ?checked ~name ~value () =
        Pages.make_input
          ?a ?checked ~typ:Pages.radio ~name ~value ()
      let int_radio ?a ?checked ~name ~value () =
        Pages.make_input
          ?a ?checked ~typ:Pages.radio ~name ~value:(string_of_int value) ()
      let float_radio ?a ?checked ~name ~value () =
        Pages.make_input
          ?a ?checked ~typ:Pages.radio ~name ~value:(string_of_float value) ()
      let user_type_radio ?a ?checked ~name ~value string_of =
        Pages.make_input
          ?a ?checked ~typ:Pages.radio ~name ~value:(string_of value) ()
      let any_radio ?a ?checked ~(name : string) ~value () =
        Pages.make_input
          ?a ?checked ~typ:Pages.radio ~name:name ~value:value ()

      let string_button ?a ~name ~value c =
        Pages.make_button ?a ~button_type:Pages.buttonsubmit ~name ~value c

      let int_button ?a ~name ~value c =
        Pages.make_button ?a ~button_type:Pages.buttonsubmit ~name ~value:(string_of_int value) c

      let float_button ?a ~name ~value c =
        Pages.make_button ?a ~button_type:Pages.buttonsubmit ~name ~value:(string_of_float value) c

      let user_type_button ?a ~name ~value string_of c =
        Pages.make_button ?a ~button_type:Pages.buttonsubmit ~name ~value:(string_of value) c

      let any_button ?a ~button_type ~name ~value c =
        Pages.make_button ?a ~button_type ~name ~value c

      let button ?a ~button_type c =
        Pages.make_button ?a ~button_type c


      let textarea ?a ~name =
        Pages.make_textarea ?a ~name:name

      type 'a soption =
          option_attrib_t
            * 'a (* Content (or value if the following is present) *)
            * pcdata_elt option (* if content different from value *)
            * bool (* selected *)
            
      type 'a select_opt = 
        | Optgroup of 
            optgroup_attrib_t
              * string (* label *)
              * 'a soption
              * 'a soption list
        | Option of 'a soption
              
      let gen_select ?a ?(multiple=false) ~name 
          (fl : 'a select_opt) (ol : 'a select_opt list) string_of =
        let make_opt (a, cv, co, sel) =
          (match co with
          | None -> Pages.make_option ~a ~selected:sel 
                (Pages.make_pcdata (string_of cv))
          | Some c -> Pages.make_option ~a ~selected:sel 
                ~value:(string_of cv) c)
        in
        let rec make_optg = function
          | Option o -> Pages.select_content_of_option (make_opt o)
          | Optgroup (a, label, og1, ogl) -> 
              Pages.make_optgroup 
                ~a ~label (make_opt og1) (Pages.map_option make_opt ogl)
        in
        let fl2,ol2 = Pages.map_optgroup make_optg fl ol in
        Pages.make_select ?a ~multiple ~name fl2 ol2

      let any_select ?a ~(name : string)
          (fl : string select_opt) (ol : string select_opt list) =
        gen_select ?a ~multiple:false ~name fl ol id

      let int_select ?a ~name 
          (fl : int select_opt) (ol : int select_opt list) =
        gen_select ?a ~multiple:false ~name fl ol string_of_int

      let float_select ?a ~name 
          (fl : float select_opt) (ol : float select_opt list) =
        gen_select ?a ~multiple:false ~name fl ol string_of_float

      let string_select ?a ~name 
          (fl : string select_opt) (ol : string select_opt list) =
        gen_select ?a ~multiple:false ~name fl ol id

      let user_type_select ?a ~name (fl : 'a select_opt) 
          (ol : 'a select_opt list) string_of =
        gen_select ?a ~multiple:false ~name fl ol string_of



      let any_multiple_select ?a ~(name : string)
          (fl : string select_opt) (ol : string select_opt list) =
        gen_select ?a ~multiple:true ~name fl ol id

      let int_multiple_select ?a ~name 
          (fl : int select_opt) (ol : int select_opt list) =
        gen_select ?a ~multiple:true ~name fl ol string_of_int

      let float_multiple_select ?a ~name 
          (fl : float select_opt) (ol : float select_opt list) =
        gen_select ?a ~multiple:true ~name fl ol string_of_float

      let string_multiple_select ?a ~name 
          (fl : string select_opt) (ol : string select_opt list) =
        gen_select ?a ~multiple:true ~name fl ol id

      let user_type_multiple_select ?a
          ~name (fl : 'a select_opt) 
          (ol : 'a select_opt list) string_of =
        gen_select ?a ~multiple:true ~name fl ol string_of

    end : ELIOMFORMSIG with 
     type form_content_elt = Pages.form_content_elt
     and type form_content_elt_list = Pages.form_content_elt_list
     and type form_elt = Pages.form_elt
     and type a_content_elt = Pages.a_content_elt
     and type a_content_elt_list = Pages.a_content_elt_list
     and type a_elt = Pages.a_elt
     and type a_elt_list = Pages.a_elt_list
     and type div_content_elt = Pages.div_content_elt
     and type div_content_elt_list = Pages.div_content_elt_list
     and type button_elt = Pages.button_elt
     and type button_content_elt = Pages.button_content_elt
     and type button_content_elt_list = Pages.button_content_elt_list

     and type uri = Pages.uri
     and type link_elt = Pages.link_elt
     and type script_elt = Pages.script_elt
     and type textarea_elt = Pages.textarea_elt
     and type select_elt = Pages.select_elt
     and type input_elt = Pages.input_elt
     and type pcdata_elt = Pages.pcdata_elt
     and type a_attrib_t = Pages.a_attrib_t
     and type form_attrib_t = Pages.form_attrib_t
     and type input_attrib_t = Pages.input_attrib_t
     and type textarea_attrib_t = Pages.textarea_attrib_t
     and type select_attrib_t = Pages.select_attrib_t
     and type link_attrib_t = Pages.link_attrib_t
     and type script_attrib_t = Pages.script_attrib_t
     and type optgroup_attrib_t = Pages.optgroup_attrib_t
     and type option_attrib_t = Pages.option_attrib_t
     and type button_attrib_t = Pages.button_attrib_t
     and type input_type_t = Pages.input_type_t
     and type button_type_t = Pages.button_type_t
    )


(*****************************************************************************)
(*****************************************************************************)
(*****************************************************************************)
(*****************************************************************************)


module Xhtmlreg_ = struct
  open XHTML.M
  open Xhtmltypes

  type page = xhtml elt

   let send ?(cookies=[]) ?charset ?code ~sp content = 
     EliomResult 
       {res_cookies= cookies;
        res_lastmodified= None;
        res_etag= None;
        res_code= code;
        res_send_page= Predefined_senders.send_xhtml_page ~content:content;
        res_headers= Predefined_senders.dyn_headers;
        res_charset= match charset with
          None -> get_config_file_charset sp
        | _ -> charset
      }

end

module Xhtmlforms_ = struct
  open XHTML.M
  open Xhtmltypes

  type form_content_elt = form_content elt
  type form_content_elt_list = form_content elt list
  type uri = XHTML.M.uri

  type a_content_elt = a_content elt
  type a_content_elt_list = a_content elt list

  type div_content_elt = div_content elt
  type div_content_elt_list = div_content elt list

  type a_elt = a elt
  type a_elt_list = a elt list
  type form_elt = form elt

  type textarea_elt = textarea elt
  type input_elt = input elt

  type link_elt = link elt
  type script_elt = script elt

  type pcdata_elt = pcdata elt

  type select_elt = select elt
  type select_content_elt = select_content elt
  type select_content_elt_list = select_content elt list
  type option_elt = selectoption elt
  type option_elt_list = selectoption elt list

  type button_elt = button elt
  type button_content_elt = button_content elt
  type button_content_elt_list = button_content elt list

  type a_attrib_t = Xhtmltypes.a_attrib XHTML.M.attrib list
  type form_attrib_t = Xhtmltypes.form_attrib XHTML.M.attrib list
  type input_attrib_t = Xhtmltypes.input_attrib XHTML.M.attrib list
  type textarea_attrib_t = Xhtmltypes.textarea_attrib XHTML.M.attrib list
  type select_attrib_t = Xhtmltypes.select_attrib XHTML.M.attrib list
  type link_attrib_t = Xhtmltypes.link_attrib XHTML.M.attrib list
  type script_attrib_t = Xhtmltypes.script_attrib XHTML.M.attrib list
  type optgroup_attrib_t = [ common | `Disabled ] XHTML.M.attrib list
  type option_attrib_t = Xhtmltypes.option_attrib XHTML.M.attrib list
  type button_attrib_t = Xhtmltypes.button_attrib XHTML.M.attrib list

  type input_type_t = 
      [ `Button
    | `Checkbox
    | `File
    | `Hidden
    | `Image
    | `Password
    | `Radio
    | `Reset
    | `Submit
    | `Text ]

  type button_type_t =
      [ `Button | `Reset | `Submit ]
        
  let hidden = `Hidden
  let checkbox = `Checkbox
  let radio = `Radio
  let submit = `Submit
  let file = `File
  let image = `Image

  let buttonsubmit = `Submit

  let uri_of_string = XHTML.M.uri_of_string

  let empty_seq = []
  let cons_form a l = a::l

  let map_option = List.map
  let map_optgroup f a l = ((f a), List.map f l)
  let select_content_of_option a = (a :> select_content_elt)

  let make_pcdata s = pcdata s

  let make_a ?(a=[]) ~href l : a_elt = 
    XHTML.M.a ~a:((a_href (uri_of_string href))::a) l

  let make_get_form ?(a=[]) ~action elt1 elts : form_elt = 
    form ~a:((a_method `Get)::a) 
      ~action:(uri_of_string action) elt1 elts

  let make_post_form ?(a=[]) ~action ?id ?(inline = false) elt1 elts 
      : form_elt = 
    let aa = (match id with
    | None -> a
    | Some i -> (a_id i)::a) 
    in
    form ~a:((XHTML.M.a_enctype "multipart/form-data")::
             (* Always Multipart!!! How to test if there is a file?? *)
             (a_method `Post)::
             (if inline then (a_class ["inline"])::aa else aa))
      ~action:(uri_of_string action) elt1 elts

  let make_hidden_field content = 
    (div ~a:[a_class ["nodisplay"]] [content] :> form_content_elt)

  let make_empty_form_content () = p [pcdata ""] (**** ŕ revoir !!!!! *)

  let remove_first = function
    | a::l -> a,l
    | [] -> (make_empty_form_content ()), []

  let make_input ?(a=[]) ?(checked=false) ~typ ?name ?src ?value () = 
    let a2 = match value with
    | None -> a
    | Some v -> (a_value v)::a
    in
    let a2 = match name with
    | None -> a2
    | Some v -> (a_name v)::a2
    in
    let a2 = match src with
    | None -> a2
    | Some v -> (a_src v)::a2
    in
    let a2 = if checked then (a_checked `Checked)::a2 else a2 in
    input ~a:((a_input_type typ)::a2) ()

  let make_button ?(a = []) ~button_type ?name ?value c =
    let a = match value with
    | None -> a
    | Some v -> (a_value v)::a
    in
    let a = match name with
    | None -> a
    | Some v -> (a_name v)::a
    in
    button ~a:((a_button_type button_type)::a) c

  let make_textarea ?(a=[]) ~name ?(value=pcdata "") ~rows ~cols () = 
    let a3 = (a_name name)::a in
    textarea ~a:a3 ~rows ~cols value

  let make_select ?(a=[]) ~multiple ~name elt elts =
    let a = if multiple then (a_multiple `Multiple)::a else a in
    select ~a:((a_name name)::a) elt elts

  let make_option ?(a=[]) ~selected ?value c =
    let a = match value with
    | None -> a
    | Some v -> (a_value v)::a
    in
    let a = if selected then (a_selected `Selected)::a else a in
    option ~a c

  let make_optgroup ?(a=[]) ~label elt elts =
    optgroup ~label ~a elt elts
    
  let make_css_link ?(a=[]) ~uri =
    link ~a:((a_href uri)::
             (a_type "text/css")::(a_rel [`Stylesheet])::a) ()
      
  let make_js_script ?(a=[]) ~uri =
    script ~a:((a_src uri)::a) ~contenttype:"text/javascript" (pcdata "")

end



(*****************************************************************************)
(*****************************************************************************)

module Xhtmlforms' = MakeForms(Xhtmlforms_)
module Xhtmlreg = MakeRegister(Xhtmlreg_)

module type XHTMLFORMSSIG = sig
(* Pasted from mli *)

  open XHTML.M
  open Xhtmltypes

  val a :
      ?a:a_attrib attrib list ->
        service:
          ('get, unit, [< get_service_kind ], 
           [< suff ], 'gn, 'pn,
           [< registrable ]) service ->
           sp:server_params -> a_content elt list -> 'get -> [> a] XHTML.M.elt
(** [a service sp cont ()] creates a link from [current] to [service]. 
   The text of
   the link is [cont]. For example [cont] may be something like
   [\[pcdata "click here"\]]. 

   The last  parameter is for GET parameters.
   For example [a service sp cont (42,"hello")]

   The [~a] optional parameter is used for extra attributes 
   (see the module XHTML.M) *)

  val css_link : ?a:(link_attrib attrib list) ->
    uri:uri -> [> link ] elt
(** Creates a [<link>] tag for a Cascading StyleSheet (CSS). *)

  val js_script : ?a:(script_attrib attrib list) ->
    uri:uri -> [> script ] elt
(** Creates a [<script>] tag to add a javascript file *)

    val make_uri :
        service:('get, unit, [< get_service_kind ],
         [< suff ], 'gn, 'pn, 
         [< registrable ]) service ->
          sp:server_params -> 'get -> uri
(** Create the text of the service. Like the [a] function, it may take
   extra parameters. *)


    val get_form :
        ?a:form_attrib attrib list ->
          service:('get, unit, [< get_service_kind ],
           [<suff ], 'gn, 'pn, 
           [< registrable ]) service ->
             sp:server_params ->
              ('gn -> form_content elt list) -> [>form] elt
(** [get_form service current formgen] creates a GET form from [current] to [service]. 
   The content of
   the form is generated by the function [formgen], that takes the names
   of page parameters as parameters. *)

    val post_form :
        ?a:form_attrib attrib list ->
          service:('get, 'post, [< post_service_kind ],
           [< suff ], 'gn, 'pn, 
           [< registrable ]) service ->
            sp:server_params ->
              ('pn -> form_content elt list) -> 'get -> [>form] elt
(** [post_form service current formgen] creates a POST form from [current] 
   to [service]. The last parameter is for GET parameters (as in the function [a]).
 *)

  type basic_input_type =
      [
    | `Hidden
    | `Password
    | `Submit
    | `Text ]

  val int_input :
      ?a:input_attrib attrib list -> input_type:[< basic_input_type ] ->
        ?name:[< int setoneopt ] param_name -> 
          ?value:int -> unit -> [> input ] elt
(** Creates an [<input>] tag for an integer *)

  val float_input :
      ?a:input_attrib attrib list -> input_type:[< basic_input_type ] ->
        ?name:[< float setoneopt ] param_name -> 
          ?value:float -> unit -> [> input ] elt
(** Creates an [<input>] tag for a float *)

  val string_input : 
      ?a:input_attrib attrib list -> input_type:[< basic_input_type ] ->
        ?name:[< string setoneopt ] param_name -> 
          ?value:string -> unit -> [> input ] elt
(** Creates an [<input>] tag for a string *)

  val user_type_input : 
      ?a:input_attrib attrib list -> input_type:[< basic_input_type ] ->
        ?name:[< 'a setoneopt ] param_name -> 
          ?value:'a -> ('a -> string) -> [> input ] elt
(** Creates an [<input>] tag for a user type *)

  val any_input :
      ?a:input_attrib attrib list -> 
        input_type:[< basic_input_type | `Reset | `Button ] ->
        ?name:string -> ?value:string -> unit -> [> input ] elt
(** Creates an untyped [<input>] tag (low level) *)

  val file_input :
      ?a:input_attrib attrib list -> 
        name:[< file_info setoneopt ] param_name -> 
          unit -> [> input ] elt
(** Creates an [<input>] tag for sending a file *)

  val image_input :
      ?a:input_attrib attrib list -> 
        name:[< coordinates oneopt ] param_name -> 
          ?src:uri -> unit -> [> input ] elt
(** Creates an [<input type="image" name="...">] tag that sends the coordinates 
   you clicked on *)
            
  val int_image_input :
      ?a:input_attrib attrib list -> 
        name:[< (int * coordinates) oneopt ] param_name -> value:int -> 
          ?src:uri -> unit -> [> input ] elt
(** Creates an [<input type="image" name="..." value="...">] tag that sends
   the coordinates you clicked on and a value of type int *)

  val float_image_input :
      ?a:input_attrib attrib list -> 
        name:[< (float * coordinates) oneopt ] param_name -> value:float -> 
          ?src:uri -> unit -> [> input ] elt
(** Creates an [<input type="image" name="..." value="...">] tag that sends
    the coordinates you clicked on and a value of type float *)

  val string_image_input :
      ?a:input_attrib attrib list -> 
        name:[< (string * coordinates) oneopt ] param_name -> value:string -> 
          ?src:uri -> unit -> [> input ] elt
(** Creates an [<input type="image" name="..." value="...">] tag that sends
   the coordinates you clicked on and a value of type string *)

  val user_type_image_input :
      ?a:input_attrib attrib list -> 
        name:[< ('a * coordinates) oneopt ] param_name -> value:'a -> 
          ?src:uri -> ('a -> string) -> [> input ] elt
(** Creates an [<input type="image" name="..." value="...">] tag that sends
   the coordinates you clicked on and a value of user defined type *)

  val any_image_input :
      ?a:input_attrib attrib list -> 
        name:string -> value:string -> ?src:uri -> unit -> [> input ] elt
(** Creates an [<input type="image" name="..." value="...">] tag that sends
   the coordinates you clicked on and an untyped value *)

  val bool_checkbox :
      ?a:input_attrib attrib list -> ?checked:bool -> 
        name:[ `One of bool ] param_name -> unit -> [> input ] elt
(** Creates a checkbox [<input>] tag that will have a boolean value.
   The service must declare a [bool] parameter.
 *)

    val int_checkbox :
        ?a:input_attrib attrib list -> ?checked:bool -> 
          name:[ `Set of int ] param_name -> value:int -> 
            unit -> [> input ] elt
(** Creates a checkbox [<input>] tag that will have an int value.
   Thus you can do several checkboxes with the same name 
   (and different values). 
   The service must declare a parameter of type [set].
 *)

    val float_checkbox :
        ?a:input_attrib attrib list -> ?checked:bool -> 
          name:[ `Set of float ] param_name -> value:float -> 
            unit -> [> input ] elt
(** Creates a checkbox [<input>] tag that will have a float value.
   Thus you can do several checkboxes with the same name 
   (and different values). 
   The service must declare a parameter of type [set].
 *)


    val string_checkbox :
        ?a:input_attrib attrib list -> ?checked:bool -> 
          name:[ `Set of string ] param_name -> value:string -> 
            unit -> [> input ] elt
(** Creates a checkbox [<input>] tag that will have a string value.
   Thus you can do several checkboxes with the same name 
   (and different values). 
   The service must declare a parameter of type [set].
 *)


    val user_type_checkbox :
        ?a:input_attrib attrib list -> ?checked:bool -> 
          name:[ `Set of 'a ] param_name -> value:'a -> 
            ('a -> string) -> [> input ] elt
(** Creates a checkbox [<input>] tag that will have a "user type" value.
   Thus you can do several checkboxes with the same name 
   (and different values). 
   The service must declare a parameter of type [set].
 *)


    val any_checkbox :
        ?a:input_attrib attrib list -> ?checked:bool -> 
          name:string -> value:string -> unit -> [> input ] elt
(** Creates a checkbox [<input>] tag with untyped content.
   Thus you can do several checkboxes with the same name 
   (and different values). 
   The service must declare a parameter of type [any].
 *)




  val string_radio : ?a:(input_attrib attrib list ) -> ?checked:bool -> 
    name:[ `Opt of string ] param_name -> value:string -> unit -> [> input ] elt
(** Creates a radio [<input>] tag with string content *)

  val int_radio : ?a:(input_attrib attrib list ) -> ?checked:bool -> 
     name:[ `Opt of int ] param_name -> value:int -> unit -> [> input ] elt
(** Creates a radio [<input>] tag with int content *)

  val float_radio : ?a:(input_attrib attrib list ) -> ?checked:bool -> 
     name:[ `Opt of float ] param_name -> value:float -> unit -> [> input ] elt
(** Creates a radio [<input>] tag with float content *)

  val user_type_radio : ?a:(input_attrib attrib list ) -> ?checked:bool ->
    name:[ `Opt of 'a ] param_name -> value:'a -> ('a -> string) -> [> input ] elt
(** Creates a radio [<input>] tag with user_type content *)

  val any_radio : ?a:(input_attrib attrib list ) -> ?checked:bool -> 
    name:string -> value:string -> unit -> [> input ] elt
(** Creates a radio [<input>] tag with untyped string content (low level) *)


  type button_type =
      [ `Button | `Reset | `Submit ]

  val string_button : ?a:(button_attrib attrib list ) -> 
    name:[< string setone ] param_name -> value:string -> 
      button_content elt list -> [> button ] elt
(** Creates a submit [<button>] tag with string content *)
  val int_button : ?a:(button_attrib attrib list ) ->
    name:[< int setone ] param_name -> value:int -> 
      button_content elt list -> [> button ] elt
(** Creates a submit [<button>] tag with int content *)
  val float_button : ?a:(button_attrib attrib list ) ->
    name:[< float setone ] param_name -> value:float -> 
      button_content elt list -> [> button ] elt
(** Creates a submit [<button>] tag with float content *)
  val user_type_button : ?a:(button_attrib attrib list ) ->
    name:[< 'a setone ] param_name -> value:'a -> ('a -> string) ->
      button_content elt list -> [> button ] elt
(** Creates a submit [<button>] tag with user_type content *)
  val any_button : ?a:(button_attrib attrib list ) ->
    button_type:[< button_type ] ->
      name:string -> value:string -> 
        button_content elt list -> [> button ] elt
(** Creates a [<button>] tag with untyped string content (low level) *)

  val button : ?a:(button_attrib attrib list ) ->
    button_type:[< button_type ] ->
      button_content elt list -> [> button ] elt
(** Creates a [<button>] tag with no value. No value is sent. *)



  val textarea : 
      ?a:textarea_attrib attrib list ->
        name:[< string setoneopt ] param_name -> 
          ?value:Xhtmltypes.pcdata XHTML.M.elt -> 
            rows:int -> cols:int -> 
              unit -> [> textarea ] elt
(** Creates a [<textarea>] tag *)

  type 'a soption =
      Xhtmltypes.option_attrib XHTML.M.attrib list
        * 'a (* Value to send *)
        * pcdata elt option (* Text to display (if different from the latter) *)
        * bool (* selected *)
        
  type 'a select_opt = 
    | Optgroup of 
        [ common | `Disabled ] XHTML.M.attrib list
          * string (* label *)
          * 'a soption
          * 'a soption list
    | Option of 'a soption
          
  (** The type for [<select>] options and groups of options.
     The field of type 'a in [soption] is the value that will be sent 
     by the form. If the [string option] is not present it is also the
     value displayed.
   *)

  val int_select :
      ?a:select_attrib attrib list ->
        name:[< `Opt of int ] param_name ->
          int select_opt ->
            int select_opt list ->
              select elt
(** Creates a [<select>] tag for int values. *)

  val float_select :
      ?a:select_attrib attrib list ->
        name:[< `Opt of float ] param_name ->
          float select_opt ->
            float select_opt list ->
              select elt
(** Creates a [<select>] tag for float values. *)

  val string_select :
      ?a:select_attrib attrib list ->
        name:[< `Opt of string ] param_name ->
          string select_opt ->
            string select_opt list ->
              select elt
(** Creates a [<select>] tag for string values. *)

  val user_type_select :
      ?a:select_attrib attrib list ->
        name:[< `Opt of 'a ] param_name ->
          'a select_opt ->
            'a select_opt list ->
              ('a -> string) ->
                select elt
(** Creates a [<select>] tag for user type values. *)

  val any_select :
      ?a:select_attrib attrib list ->
        name:string ->
          string select_opt ->
            string select_opt list ->
              select elt
(** Creates a [<select>] tag for any (untyped) value. *)


  val int_multiple_select :
      ?a:select_attrib attrib list ->
        name:[< `Set of int ] param_name ->
          int select_opt ->
            int select_opt list ->
              select elt
(** Creates a [<select>] tag for int values. *)

  val float_multiple_select :
      ?a:select_attrib attrib list ->
        name:[< `Set of float ] param_name ->
          float select_opt ->
            float select_opt list ->
              select elt
(** Creates a [<select>] tag for float values. *)

  val string_multiple_select :
      ?a:select_attrib attrib list ->
        name:[< `Set of string ] param_name ->
          string select_opt ->
            string select_opt list ->
              select elt
(** Creates a [<select>] tag for string values. *)

  val user_type_multiple_select :
      ?a:select_attrib attrib list ->
        name:[< `Set of 'a ] param_name ->
          'a select_opt ->
            'a select_opt list ->
              ('a -> string) ->
                select elt
(** Creates a [<select>] tag for user type values. *)

  val any_multiple_select :
      ?a:select_attrib attrib list ->
        name:string ->
          string select_opt ->
            string select_opt list ->
              select elt
(** Creates a [<select>] tag for any (untyped) value. *)


end


module Xhtmlforms : XHTMLFORMSSIG = struct

  open XHTML.M
  open Xhtmltypes
  include Xhtmlforms'

(* As we want -> [> a ] elt and not -> [ a ] elt (etc.), 
   we define a new module: *)
  let a = (a :
      ?a:a_attrib attrib list ->
        service:('get, unit, [< get_service_kind ], 
         [< suff ], 'gn, 'pn,
         [< registrable ]) service ->
           sp:server_params -> a_content elt list -> 'get -> 
             a XHTML.M.elt :>
      ?a:a_attrib attrib list ->
        service:('get, unit, [< get_service_kind ], 
         [< suff ], 'gn, 'pn,
         [< registrable ]) service ->
           sp:server_params -> a_content elt list -> 'get -> 
             [> a] XHTML.M.elt)

  let css_link = (css_link :
                    ?a:(link_attrib attrib list) ->
                      uri:uri -> link elt :>
                    ?a:(link_attrib attrib list) ->
                      uri:uri -> [> link ] elt)

  let js_script = (js_script : 
                     ?a:(script_attrib attrib list) ->
                       uri:uri -> script elt :>
                     ?a:(script_attrib attrib list) ->
                       uri:uri -> [> script ] elt)

  let make_uri = (make_uri :
      service:('get, unit, [< get_service_kind ],
       [< suff ], 'gn, 'pn, 
       [< registrable ]) service ->
         sp:server_params -> 'get -> uri)

  let get_form = (get_form :
      ?a:form_attrib attrib list ->
        service:('get, unit, [< get_service_kind ],
         [<suff ], 'gn, 'pn, 
         [< registrable ]) service ->
           sp:server_params ->
             ('gn -> form_content elt list) -> form elt :>
      ?a:form_attrib attrib list ->
        service:('get, unit, [< get_service_kind ],
         [<suff ], 'gn, 'pn, 
         [< registrable ]) service ->
           sp:server_params ->
             ('gn -> form_content elt list) -> [> form ] elt)

  let post_form = (post_form :
      ?a:form_attrib attrib list ->
        service:('get, 'post, [< post_service_kind ],
         [< suff ], 'gn, 'pn, 
         [< registrable ]) service ->
          sp:server_params ->
            ('pn -> form_content elt list) -> 'get -> form elt :>
      ?a:form_attrib attrib list ->
        service:('get, 'post, [< post_service_kind ],
         [< suff ], 'gn, 'pn, 
         [< registrable ]) service ->
          sp:server_params ->
            ('pn -> form_content elt list) -> 'get -> [> form ] elt)

  type basic_input_type = 
      [
    | `Hidden
    | `Password
    | `Submit
    | `Text ]

  type full_input_type =
    [ `Button
    | `Checkbox
    | `File
    | `Hidden
    | `Image
    | `Password
    | `Radio
    | `Reset
    | `Submit
    | `Text ]

  let int_input = (int_input :
      ?a:input_attrib attrib list -> input_type:full_input_type ->
        ?name:'a -> ?value:int -> unit -> input elt :>
      ?a:input_attrib attrib list -> input_type:[< basic_input_type] ->
        ?name:'a -> ?value:int -> unit -> [> input ] elt)

  let float_input = (float_input :
      ?a:input_attrib attrib list -> input_type:full_input_type ->
        ?name:'a -> ?value:float -> unit -> input elt :>
      ?a:input_attrib attrib list -> input_type:[< basic_input_type] ->
        ?name:'a -> ?value:float -> unit -> [> input ] elt)

  let string_input = (string_input : 
      ?a:input_attrib attrib list -> input_type:full_input_type ->
        ?name:'a -> ?value:string -> unit -> input elt :>
      ?a:input_attrib attrib list -> input_type:[< basic_input_type] ->
        ?name:'a -> ?value:string -> unit -> [> input ] elt)

  let user_type_input = (user_type_input : 
      ?a:input_attrib attrib list -> input_type:full_input_type ->
        ?name:'b -> ?value:'a -> ('a -> string) -> input elt :>
      ?a:input_attrib attrib list -> input_type:[< basic_input_type] ->
        ?name:'b -> ?value:'a -> ('a -> string) -> [> input ] elt)

  let any_input = (any_input :
      ?a:input_attrib attrib list -> input_type:full_input_type ->
        ?name:string -> ?value:string -> unit -> input elt :>
      ?a:input_attrib attrib list -> 
        input_type:[< basic_input_type | `Button | `Reset ] ->
        ?name:string -> ?value:string -> unit -> [> input ] elt)

  let file_input = (file_input :
      ?a:input_attrib attrib list -> name:'a -> 
        unit -> input elt :>
      ?a:input_attrib attrib list -> name:'a -> 
        unit -> [> input ] elt)

  let image_input = (image_input :
      ?a:input_attrib attrib list -> name:'a -> 
        ?src:uri -> unit -> input elt :>
      ?a:input_attrib attrib list -> name:'a -> 
        ?src:uri -> unit -> [> input ] elt)
            
  let int_image_input = (int_image_input :
      ?a:input_attrib attrib list -> 
        name:'a -> value:int -> 
          ?src:uri -> unit -> input elt :>
      ?a:input_attrib attrib list -> 
        name:'a -> value:int -> 
          ?src:uri -> unit -> [> input ] elt)

  let float_image_input = (float_image_input :
      ?a:input_attrib attrib list -> 
        name:'a -> value:float -> 
          ?src:uri -> unit -> input elt :>
      ?a:input_attrib attrib list -> 
        name:'a -> value:float -> 
          ?src:uri -> unit -> [> input ] elt)

  let string_image_input = (string_image_input :
      ?a:input_attrib attrib list -> 
        name:'a -> value:string -> 
          ?src:uri -> unit -> input elt :>
      ?a:input_attrib attrib list -> 
        name:'a -> value:string -> 
          ?src:uri -> unit -> [> input ] elt)

  let user_type_image_input = (user_type_image_input :
      ?a:input_attrib attrib list -> 
        name:'b -> value:'a -> 
          ?src:uri -> ('a -> string) -> input elt :>
      ?a:input_attrib attrib list -> 
        name:'b -> value:'a -> 
          ?src:uri -> ('a -> string) -> [> input ] elt)

  let any_image_input = (any_image_input :
      ?a:input_attrib attrib list -> 
        name:string -> value:string -> ?src:uri -> unit -> input elt :>
      ?a:input_attrib attrib list -> 
        name:string -> value:string -> ?src:uri -> unit -> [> input ] elt)

  let bool_checkbox = (bool_checkbox :
      ?a:(input_attrib attrib list ) -> ?checked:bool -> 
        name:'a -> unit -> input elt :>
      ?a:(input_attrib attrib list ) -> ?checked:bool -> 
        name:'a -> unit -> [> input ] elt)

  let int_checkbox = (int_checkbox :
      ?a:input_attrib attrib list -> ?checked:bool -> 
        name:[ `Set of int ] param_name -> value:int -> unit -> input elt :>
      ?a:input_attrib attrib list -> ?checked:bool -> 
        name:[ `Set of int ] param_name -> value:int -> unit -> [> input ] elt)

  let float_checkbox = (float_checkbox :
      ?a:input_attrib attrib list -> ?checked:bool -> 
        name:[ `Set of float ] param_name -> value:float -> unit -> input elt :>
      ?a:input_attrib attrib list -> ?checked:bool -> 
        name:[ `Set of float ] param_name -> value:float -> unit -> [> input ] elt)

  let string_checkbox = (string_checkbox :
      ?a:input_attrib attrib list -> ?checked:bool -> 
        name:[ `Set of string ] param_name -> value:string -> unit -> input elt :>
      ?a:input_attrib attrib list -> ?checked:bool -> 
        name:[ `Set of string ] param_name -> value:string -> unit -> [> input ] elt)

  let user_type_checkbox = (user_type_checkbox :
      ?a:input_attrib attrib list -> ?checked:bool -> 
        name:[ `Set of 'a ] param_name -> value:'a -> ('a -> string) -> input elt :>
      ?a:input_attrib attrib list -> ?checked:bool -> 
        name:[ `Set of 'a ] param_name -> value:'a -> ('a -> string) -> [> input ] elt)

  let any_checkbox = (any_checkbox :
      ?a:input_attrib attrib list -> ?checked:bool -> 
        name:string -> value:string -> unit -> input elt :>
      ?a:input_attrib attrib list -> ?checked:bool -> 
        name:string -> value:string -> unit -> [> input ] elt)


  let string_radio = (string_radio : 
    ?a:(input_attrib attrib list ) -> ?checked:bool -> 
      name:'a -> value:string -> unit -> input elt :>
    ?a:(input_attrib attrib list ) -> ?checked:bool -> 
      name:'a -> value:string -> unit -> [> input ] elt)

  let int_radio = (int_radio : 
                     ?a:(input_attrib attrib list ) -> ?checked:bool -> 
     name:'a -> value:int -> unit -> input elt :>
                     ?a:(input_attrib attrib list ) -> ?checked:bool -> 
     name:'a -> value:int -> unit -> [> input ] elt)

  let float_radio = (float_radio : 
                       ?a:(input_attrib attrib list ) -> ?checked:bool -> 
     name:'a -> value:float -> unit -> input elt :>
                       ?a:(input_attrib attrib list ) -> ?checked:bool -> 
     name:'a -> value:float -> unit -> [> input ] elt)

  let user_type_radio = (user_type_radio : 
                           ?a:(input_attrib attrib list ) -> ?checked:bool ->
    name:'b -> value:'a -> ('a -> string) -> input elt :>
                           ?a:(input_attrib attrib list ) -> ?checked:bool ->
    name:'b -> value:'a -> ('a -> string) -> [> input ] elt)

  let any_radio = (any_radio : 
                     ?a:(input_attrib attrib list ) -> ?checked:bool -> 
    name:string -> value:string -> unit -> input elt :>
                     ?a:(input_attrib attrib list ) -> ?checked:bool -> 
    name:string -> value:string -> unit -> [> input ] elt)

  let textarea = (textarea : 
        ?a:textarea_attrib attrib list ->
          name:'a -> ?value:Xhtmltypes.pcdata XHTML.M.elt -> 
            rows:int -> cols:int -> 
              unit -> textarea elt :>
        ?a:textarea_attrib attrib list ->
          name:'a -> ?value:Xhtmltypes.pcdata XHTML.M.elt -> 
            rows:int -> cols:int -> 
              unit -> [> textarea ] elt)

  let any_select = (any_select : 
        ?a:select_attrib attrib list ->
          name:string -> 
            string select_opt -> 
              string select_opt list -> select elt :>
       ?a:select_attrib attrib list ->
         name:string -> 
           string select_opt -> 
             string select_opt list -> [> select ] elt)

  let int_select = (int_select : 
        ?a:select_attrib attrib list ->
          name:'a -> 
            int select_opt -> 
              int select_opt list -> select elt :>
       ?a:select_attrib attrib list ->
         name:'a -> 
           int select_opt -> 
             int select_opt list -> [> select ] elt)

  let float_select = (float_select : 
        ?a:select_attrib attrib list ->
          name:'a -> 
            float select_opt -> 
              float select_opt list -> select elt :>
       ?a:select_attrib attrib list ->
         name:'a -> 
           float select_opt -> 
             float select_opt list -> [> select ] elt)

  let string_select = (string_select : 
        ?a:select_attrib attrib list ->
          name:'a -> 
            string select_opt -> 
              string select_opt list -> select elt :>
       ?a:select_attrib attrib list ->
         name:'a -> 
           string select_opt -> 
             string select_opt list -> [> select ] elt)

  let user_type_select = (user_type_select : 
        ?a:select_attrib attrib list ->
          name:'b -> 
            'a select_opt -> 
              'a select_opt list -> ('a -> string) -> select elt :>
       ?a:select_attrib attrib list ->
         name:'b -> 
           'a select_opt -> 
             'a select_opt list -> ('a -> string) -> [> select ] elt)
      

  let any_multiple_select = (any_multiple_select : 
        ?a:select_attrib attrib list ->
          name:string -> 
            string select_opt -> 
              string select_opt list -> select elt :>
       ?a:select_attrib attrib list ->
         name:string -> 
           string select_opt -> 
             string select_opt list -> [> select ] elt)

  let int_multiple_select = (int_multiple_select : 
        ?a:select_attrib attrib list ->
          name:'a -> 
            int select_opt -> 
              int select_opt list -> select elt :>
       ?a:select_attrib attrib list ->
         name:'a -> 
           int select_opt -> 
             int select_opt list -> [> select ] elt)

  let float_multiple_select = (float_multiple_select : 
        ?a:select_attrib attrib list ->
          name:'a -> 
            float select_opt -> 
              float select_opt list -> select elt :>
       ?a:select_attrib attrib list ->
         name:'a -> 
           float select_opt -> 
             float select_opt list -> [> select ] elt)

  let string_multiple_select = (string_multiple_select : 
        ?a:select_attrib attrib list ->
          name:'a -> 
            string select_opt -> 
              string select_opt list -> select elt :>
       ?a:select_attrib attrib list ->
         name:'a -> 
           string select_opt -> 
             string select_opt list -> [> select ] elt)

  let user_type_multiple_select = (user_type_multiple_select : 
        ?a:select_attrib attrib list ->
          name:'b -> 
            'a select_opt -> 
              'a select_opt list -> ('a -> string) -> select elt :>
       ?a:select_attrib attrib list ->
         name:'b -> 
           'a select_opt -> 
             'a select_opt list -> ('a -> string) -> [> select ] elt)
      
  type button_type =
      [ `Button
    | `Reset
    | `Submit
      ]

  let string_button = (string_button : 
       ?a:button_attrib attrib list -> 
           name:'a -> value:string -> 
             button_content elt list -> button elt :>
       ?a:button_attrib attrib list -> 
           name:'a -> value:string -> 
             button_content elt list -> [> button ] elt)

  let int_button = (int_button : 
       ?a:button_attrib attrib list -> 
           name:'a -> value:int -> 
             button_content elt list -> button elt :>
       ?a:button_attrib attrib list -> 
           name:'a -> value:int -> 
             button_content elt list -> [> button ] elt)

  let float_button = (float_button : 
       ?a:button_attrib attrib list -> 
           name:'a -> value:float -> 
             button_content elt list -> button elt :>
       ?a:button_attrib attrib list -> 
           name:'a -> value:float -> 
             button_content elt list -> [> button ] elt)

  let user_type_button = (user_type_button : 
       ?a:button_attrib attrib list -> 
           name:'b -> value:'a -> 
             ('a -> string) ->
               button_content elt list -> button elt :>
       ?a:button_attrib attrib list -> 
           name:'b -> value:'a -> 
             ('a -> string) ->
               button_content elt list -> [> button ] elt)

  let any_button = (any_button : 
       ?a:button_attrib attrib list -> 
         button_type:button_type ->
           name:string -> value:string -> 
             button_content elt list -> button elt :>
       ?a:button_attrib attrib list -> 
         button_type:[< button_type ] ->
           name:string -> value:string -> 
             button_content elt list -> [> button ] elt)

  let button = (button : 
       ?a:button_attrib attrib list -> 
         button_type:button_type ->
           button_content elt list -> button elt :>
       ?a:button_attrib attrib list -> 
         button_type:[< button_type ] ->
           button_content elt list -> [> button ] elt)
end


module Xhtml = struct
  include Xhtmlforms
  include Xhtmlreg
end

(****************************************************************************)
(****************************************************************************)
module SubXhtml = functor(T : sig type content end) ->
  (struct
    module Cont_content =
      (* Pasted from predefined_senders.ml and modified *)
      struct
        type t = T.content XHTML.M.elt list
              
        let get_etag_aux x =
          Digest.to_hex (Digest.string x)
            
        let get_etag c =
          let x = (XHTML.M.ocsigen_xprint c) in
          get_etag_aux x
            
        let stream_of_content c = 
          let x = (XHTML.M.ocsigen_xprint c) in
          let md5 = get_etag_aux x in
          Lwt.return (Some (Int64.of_int (String.length x)), 
                      md5,
                      (Ocsistream.new_stream x 
                         (fun () -> Lwt.return (Ocsistream.empty_stream None))),
                      return
                     )
            
            (*il n'y a pas encore de parser pour ce type*)
        let content_of_stream s = assert false
      end
        
    module Cont_sender = FHttp_sender(Cont_content)
        
            
    let send_cont_page =
      Predefined_senders.send_generic 
        Cont_sender.send
        ~contenttype:"text/html"

        
    module Contreg_ = struct
      open XHTML.M
      open Xhtmltypes
        
      type page = T.content XHTML.M.elt list
            
      let send ?(cookies=[]) ?charset ?code ~sp content = 
        EliomResult 
          {res_cookies= cookies;
           res_lastmodified= None;
           res_etag= None;
           res_code= code;
           res_send_page= send_cont_page ~content:content;
           res_headers= Predefined_senders.dyn_headers;
           res_charset= match charset with
             None -> get_config_file_charset sp
           | _ -> charset
         }
          
    end
        
    module Contreg = MakeRegister(Contreg_)

    include Xhtmlforms
    include Contreg

  end : sig
    
    include ELIOMREGSIG with type page = T.content XHTML.M.elt list
    include XHTMLFORMSSIG
        
  end)

module Blocks = SubXhtml(struct
  type content = Xhtmltypes.body_content
end)


(****************************************************************************)
(****************************************************************************)

module Textreg_ = struct
  open XHTML.M
  open Xhtmltypes

  type page = (string * string)

  let send ?(cookies=[]) ?charset ?code ~sp (content, contenttype) = 
    EliomResult
      {res_cookies= cookies;
       res_lastmodified= None;
       res_etag= None;
       res_code= code;
       res_send_page= Predefined_senders.send_text_page 
         ~contenttype:contenttype ~content:content;
       res_headers= Predefined_senders.dyn_headers;
       res_charset= match charset with
          None -> get_config_file_charset sp
        | _ -> charset
     }

end

module Text = MakeRegister(Textreg_)

(****************************************************************************)
(****************************************************************************)

module CssTextreg_ = struct
  open XHTML.M
  open Xhtmltypes

  type page = string

  let send ?(cookies=[]) ?charset ?code ~sp content = 
    EliomResult
      {res_cookies= cookies;
       res_lastmodified= None;
       res_etag= None;
       res_code= code;
       res_send_page= Predefined_senders.send_text_page 
         ~contenttype:"text/css" ~content:content;
       res_headers= Predefined_senders.dyn_headers;
       res_charset= match charset with
          None -> get_config_file_charset sp
        | _ -> charset
     }

end

module CssText = MakeRegister(CssTextreg_)


(****************************************************************************)
(****************************************************************************)

module HtmlTextreg_ = struct
  open XHTML.M
  open Xhtmltypes

  type page = string

  let send ?(cookies=[]) ?charset ?code ~sp content = 
    EliomResult
      {res_cookies= cookies;
       res_lastmodified= None;
       res_etag= None;
       res_code= code;
       res_send_page= Predefined_senders.send_text_page 
         ~contenttype:"text/html" ~content:content;
       res_headers= Predefined_senders.dyn_headers;
       res_charset= match charset with
          None -> get_config_file_charset sp
        | _ -> charset
     }

end

module HtmlTextforms_ = struct
  open XHTML.M
  open Xhtmltypes

  type form_content_elt = string
  type form_content_elt_list = string
  type uri = string
  type a_content_elt = string
  type a_content_elt_list = string
  type div_content_elt = string
  type div_content_elt_list = string

  type a_elt = string
  type a_elt_list = string
  type form_elt = string

  type textarea_elt = string
  type input_elt = string
  type select_elt = string
  type select_content_elt = string
  type select_content_elt_list = string
  type option_elt = string
  type option_elt_list = string
  type button_elt = string
  type button_content_elt = string
  type button_content_elt_list = string

  type link_elt = string
  type script_elt = string

  type pcdata_elt = string

  type a_attrib_t = string
  type form_attrib_t = string
  type input_attrib_t = string
  type textarea_attrib_t = string
  type select_attrib_t = string
  type link_attrib_t = string
  type script_attrib_t = string
  type optgroup_attrib_t = string
  type option_attrib_t = string
  type button_attrib_t = string

  type input_type_t = string
  type button_type_t = string

  let hidden = "hidden"
(*  let text = "text"
  let password = "password" *)
  let checkbox = "checkbox"
  let radio = "radio"
  let submit = "submit"
  let file = "file"
  let image = "image"

  let buttonsubmit = "submit"

  let uri_of_string x = x

  let empty_seq = ""
  let cons_form a l = a^l

  let map_option f =
    List.fold_left (fun d a -> d^(f a)) ""
  
  let map_optgroup f a l = 
    ((f a), List.fold_left (fun d a -> d^(f a)) "" l)
  
  let select_content_of_option = id

  let make_pcdata = id

  let make_a ?(a="") ~href l : a_elt = 
    "<a href=\""^href^"\""^a^">"^(* List.fold_left (^) "" l *) l^"</a>"

  let make_get_form ?(a="") ~action elt1 elts : form_elt = 
    "<form method=\"get\" action=\""^(uri_of_string action)^"\""^a^">"^
    elt1^(*List.fold_left (^) "" elts *) elts^"</form>"

  let make_post_form ?(a="") ~action ?id ?(inline = false) elt1 elts 
      : form_elt = 
    let aa = "enctype=\"multipart/form-data\" "
        (* Always Multipart!!! How to test if there is a file?? *)
      ^(match id with
        None -> a
      | Some i -> " id="^i^" "^a)
    in
    "<form method=\"post\" action=\""^(uri_of_string action)^"\""^
    (if inline then "style=\"display: inline\"" else "")^aa^">"^
    elt1^(* List.fold_left (^) "" elts*) elts^"</form>"

  let make_hidden_field content = 
    "<div style=\"display: none\""^content^"</div>"

  let remove_first l = "",l

  let make_input ?(a="") ?(checked=false) ~typ ?name ?src ?value () = 
    let a2 = match value with
      None -> a
    | Some v -> " value="^v^" "^a
    in
    let a2 = match name with
      None -> a2
    | Some v -> " name="^v^" "^a2
    in
    let a2 = match src with
      None -> a2
    | Some v -> " src="^v^" "^a2
    in
    let a2 = if checked then " checked=\"checked\" "^a2 else a2 in
    "<input type=\""^typ^"\" "^a2^"/>"

  let make_button ?(a="") ~button_type ?name ?value c = 
    let a2 = match value with
      None -> a
    | Some v -> " value="^v^" "^a
    in
    let a2 = match name with
      None -> a2
    | Some v -> " name="^v^" "^a2
    in
    "<button type=\""^button_type^"\" "^a2^">"^c^"</button>"

  let make_textarea ?(a="") ~name:name ?(value="") ~rows ~cols () = 
    "<textarea name=\""^name^"\" rows=\""^(string_of_int rows)^
    "\" cols=\""^(string_of_int cols)^"\" "^a^">"^value^"</textarea>"

  let make_select ?(a="") ~multiple ~name elt elts = 
    "<select "^(if multiple then "multiple=\"multiple\" " else "")^
    "name=\""^name^"\" "^a^">"^elt^elts^"</select>"

  let make_option ?(a="") ~selected ?value c = 
    let a = match value with
      None -> a
    | Some v -> " value="^v^" "^a
    in
    "<option "^(if selected then "selected=\"selected\" " else "")^
    a^">"^c^"</option>"

  let make_optgroup ?(a="") ~label elt elts = 
    "<optgroup label=\""^label^"\" "^
    a^">"^elt^elts^"</optgroup>"


  let make_css_link ?(a="") ~uri =
    "<link href=\""^uri^" type=\"text/css\" rel=\"stylesheet\" "^a^"/>"
                                                                      
  let make_js_script ?(a="") ~uri =
    "<script src=\""^uri^" contenttype=\"text/javascript\" "^a^"></script>"

end



(****************************************************************************)
(****************************************************************************)

module HtmlTextforms = MakeForms(HtmlTextforms_)
module HtmlTextreg = MakeRegister(HtmlTextreg_)

module HtmlText = struct
  include HtmlTextforms
  include HtmlTextreg
end


(****************************************************************************)
(****************************************************************************)

(** Actions are like services, but do not generate any page. The current
   page is reloaded. *)
module Actionreg_ = struct
  open XHTML.M
  open Xhtmltypes

  type page = exn list

  let send ?(cookies=[]) ?charset ?code ~sp content =
    EliomExn (content, cookies)

end

module Actions = MakeRegister(Actionreg_)


(** Unit services are like services, do not generate any page, and do not
    reload the page. To be used carefully. Probably not usefull at all. *)
module Unitreg_ = struct
  open XHTML.M
  open Xhtmltypes

  type page = unit

  let send ?(cookies=[]) ?charset ?(code = 204) ~sp content = 
    EliomResult
      {res_cookies= cookies;
       res_lastmodified= None;
       res_etag= None;
       res_code= Some code;
       res_send_page= Predefined_senders.send_empty ~content:content;
       res_headers= [];
       res_charset= None
     }

end


module Unit = MakeRegister(Unitreg_)


(** Redirection services are like services, but send a redirection instead
 of a page. 
   
   The HTTP/1.1 RFC says:
   If the 301 status code is received in response to a request other than GET or HEAD, the user agent MUST NOT automatically redirect the request unless it can be confirmed by the user, since this might change the conditions under which the request was issued.

   Here redirections are done towards services without parameters.
   (possibly preapplied).

 *)
module Redirreg_ = struct
  open XHTML.M
  open Xhtmltypes

  type page = string

  let send ?(cookies=[]) ?charset ?(code = 301) ~sp content =
    EliomResult
      {res_cookies= cookies;
       res_lastmodified= None;
       res_etag= None;
       res_code= Some code; (* Moved permanently *)
       res_send_page= 
       (fun ?cookies waiter ~clientproto ?code ?etag ~keep_alive
           ?last_modified ?location ~head ?headers ?charset s ->
             Predefined_senders.send_empty
               ~content:() 
               ?cookies
               waiter 
               ~clientproto
               ?code
               ?etag ~keep_alive
               ?last_modified 
               ~location:content
               ~head ?headers ?charset s);
       res_headers= [];
       res_charset= None
     }

end


module Redirections = MakeRegister(Redirreg_)


(* Any is a module allowing to register service that decide themselves
   what they want to send.
 *)
module Anyreg_ = struct
  open XHTML.M
  open Xhtmltypes

  type page = result_to_send

  let send ?(cookies=[]) ?charset ?code ~sp content = 
    match content with
    | EliomResult res ->
        EliomResult
          {res with 
           res_cookies=cookies@res.res_cookies;
           res_charset= match charset with
           | None -> res.res_charset
           | _ -> charset
         }
    | EliomExn (e, c) -> 
        EliomExn (e, cookies@c)

end

module Any = MakeRegister(Anyreg_)


(* Files is a module allowing to register services that send files *)
module Filesreg_ = struct
  open XHTML.M
  open Xhtmltypes

  type page = string

  let send ?(cookies=[]) ?charset ?code ~sp filename = 
    let (filename, stat) =
      (try
        (* That piece of code has been pasted from staticmod.ml *)
        let stat = Unix.LargeFile.stat filename in
        let (filename, stat) = 
          Messages.debug ("Eliom.Files - Testing \""^filename^"\".");
          let path = get_current_path sp in
          if (stat.Unix.LargeFile.st_kind = Unix.S_DIR)
          then 
            if (filename.[(String.length filename) - 1]) = '/'
            then
              let fn2 = filename^"index.html" in
              Messages.debug ("Eliom.Files - Testing \""^fn2^"\".");
              (fn2,(Unix.LargeFile.stat fn2))
            else
              (if (path= []) || (path = [""])
              then 
                let fn2 = filename^"/index.html" in
                Messages.debug ("Eliom.Files - Testing \""^fn2^"\".");
                (fn2,(Unix.LargeFile.stat fn2))
              else (Messages.debug ("Eliom.Files - "^filename^" is a directory");
                    raise Ocsigen_Is_a_directory))
          else (filename, stat)
        in
        Messages.debug ("Eliom.Files - Looking for \""^filename^"\".");
        
        if (stat.Unix.LargeFile.st_kind 
              = Unix.S_REG)
        then begin
          Unix.access filename [Unix.R_OK];
          (filename, stat)
        end
        else raise Ocsigen_404 (* ??? *)
      with
        (Unix.Unix_error (Unix.EACCES,_,_))
      | Ocsigen_Is_a_directory
      | Ocsigen_malformed_url as e -> raise e
      | e -> raise Ocsigen_404)
    in
    EliomResult
      {res_cookies= cookies;
       res_lastmodified= Some stat.Unix.LargeFile.st_mtime;
       res_etag= Some (Predefined_senders.File_content.get_etag filename);
       res_code= code;
       res_send_page= Predefined_senders.send_file ~content:filename;
       res_headers= [];
       res_charset= match charset with
         None -> get_config_file_charset sp
       | _ -> charset
     }


end

module Files = MakeRegister(Filesreg_)

(*****************************************************************************)
(** {2 persistent sessions} *)

open Ocsipersist

type 'a persistent_table = (int64 * 'a) Ocsipersist.table

let create_persistent_table = create_persistent_table

let get_persistent_data ~table ~sp =
  match (get_persistent_cookie sp) with
  | Some (c, k) -> 
      (catch
         (fun () ->
           find table c >>=
           (fun (k2, v) ->
             if k2 = k
             then return (Some v)
             else begin
               remove table c >>= (* It was an old cookie. I don't trust it! *)
               (fun () -> return None)
             end))
         (fun _ -> return None)) (* ?? If an error occurs, assume no data *)
         (* function 
           | Not_found -> return None
           | e -> fail e) *)
  | None -> return None

let set_persistent_data ~table ~sp ~value =
  create_persistent_cookie sp >>=
  (fun (c, k) -> add table c (k, value))

let remove_persistent_data ~table ~sp =
  match get_persistent_cookie sp with
  | Some (c,k) -> remove table c
  | None -> return ()

(*****************************************************************************)
(** {2 session data in memory} *)
type 'a table = 'a Cookies.t

let create_table ?sp () = 
  match sp with
  | None -> 
      (match global_register_allowed () with
      | Some get_current_hostdir -> create_table ()
      | None -> raise (Eliom_function_forbidden_outside_site_loading
                         "create_table"))
  | Some sp -> create_table_during_session sp


let get_session_data ~table ~sp =
  match (get_cookie sp) with
  | Some c -> 
      (try
        Some (Cookies.find table c)
      with _ -> None)
  | None -> None

let set_session_data ~table ~sp ~value =
  let c = create_cookie sp in
  Cookies.replace table c value

let remove_session_data ~table ~sp =
  match get_cookie sp with
  | Some c -> Cookies.remove table c
  | None -> ()

(*****************************************************************************)
(** Close a session *)
let close_persistent_session ~sp:(_,si,_) =
  (match !(si.si_persistent_cookie) with
  | Some (c, _) -> 
      catch
        (fun () -> remove_from_all_persistent_tables c)
        (fun _ -> return ())
  | None -> return ()) >>=
  (fun () ->
    si.si_persistent_cookie := None;
    return ())

let close_volatile_session ~sp:((_, si, (_,(_,_,_),sesstab,_,_)) as sp) = 
  remove_session sp;
  sesstab := empty_tables ();
  si.si_cookie := None

let close_session ~sp =
  close_volatile_session sp;
  close_persistent_session sp


(*****************************************************************************)
(* Exploration *)

let number_of_sessions = number_of_sessions

let number_of_tables = Eliommod.number_of_tables

let number_of_table_elements = number_of_table_elements

let number_of_persistent_sessions = number_of_persistent_sessions

let number_of_persistent_tables = number_of_persistent_tables
  (* One table is the main table of sessions *)

let number_of_persistent_table_elements () =
  number_of_persistent_table_elements ()
