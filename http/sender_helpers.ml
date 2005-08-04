(** this module provides helpers fonctions to create senders*)

open Http_frame
open Http_com
open Lwt

(** this module instantiate the HTTP_CONTENT signature for an Xhtml content*)
module Xhtml_content =
  struct
    type t = Xhtmlpp.xhtml
    let string_of_content c = Xhtmlpp.xh_print c
    (*il n'y a pas encore de parser pour ce type*)
    let content_of_string s =assert false
  end


let read_file ?(buffer_size=512) fd =
  let rec read_aux (res:string) =
    function
      |0 ->  return res
      |_ ->
          let buf = String.create buffer_size in
          Lwt_unix.read fd buf 0 buffer_size >>=
            (fun nb_lu -> 
              let str_lu = String.sub buf 0 nb_lu in
              read_aux (res^str_lu) nb_lu
            )
  in let buf = String.create buffer_size in
  Lwt_unix.read fd buf 0 buffer_size >>=
    (fun nb_lu ->
      let str_lu = String.sub buf 0 nb_lu in
      read_aux str_lu nb_lu 
     
    )

(** this module instanciate the HTTP_CONTENT signature for the files*)
module File_content =
  struct
    type t = string (*nom du fichier*)
    let string_of_content c  =
      (*ouverture du fichier*)
      let fd = Unix.openfile c [Unix.O_RDONLY;Unix.O_NONBLOCK] 0o666 in
      Lwt_unix.run (read_file fd )

    let content_of_string s = assert false
      
  end

(** this module is a Http_frame with Xhtml content*)
module Xhtml_htttp_frame = FHttp_frame (Xhtml_content)

(** this module is a sender that send Http_frame with Xhtml content*)
module Xhtml_sender = FHttp_sender(Xhtml_content)

(** this module is a Http_frame with file content*) 
module File_http_frame = FHttp_frame (File_content)

(** this module is a sender that send Http_frame with file content*)
module File_sender = FHttp_sender(File_content)

(** fonction that create a sender with xhtml content
server_name is the name of the server send in the HTTP header
proto is the protocol, default is HTTP/1.1
fd is the Unix file descriptor *)
let create_xhtml_sender ?server_name ?proto fd =
  let hd =
    match server_name with
    |None -> []
    |Some s -> [("Server",s)]
  in
  let hd2 =
    [
      ("Accept-Ranges","bytes");
      ("Cache-Control","no-cache");
      ("Content-Type","text/html")
    ]@hd
  in
  match proto with
  |None ->
      Xhtml_sender.create ~headers:hd2 fd
  |Some p -> 
      Xhtml_sender.create ~headers:hd2 ~proto:p fd

(** fonction that sends a xhtml page
* code is the code of the http answer
* keep_alive is a boolean value that set the field Connection
* cookie is a string value that give a value to the session cookie
* page is the page to send
* xhtml_sender is the used sender*)
let send_page ?code ?keep_alive ?cookie page xhtml_sender =
  (*debug*)
  print_endline "d�but send_page";
  (*ajout des option sp�cifique � la page*)
  (*ici il faudrait r�cup�rer la valeur e la commande date*)
  let date = "Tue, 31 May 2006 16:34:59 GMT" in
  (*ici il faudrait r�cup�rer la valeur de la commande uname*)
  let server = "ploplop (Unix) (Gentoo/Linux) omlet"in
  (*il faut r�cup�rer la date de derni�re modification si ca a une
  * signification*)
  let last_mod = "Wed, 20 Oct 1900 12:51:24 GMT" in 
  (*debug*)
  print_endline "avant_hds";
  let hds = 
    [
      ("Date",date);
      ("Last-Modified",last_mod);
    ]
  in
  print_endline "avant hds2";
  let hds2 =
    match cookie with
    |None -> hds
    |Some c -> ("Set-Cookie","session="^c)::hds
  in
  print_endline "avant hds3";
  let hds3 =
    match keep_alive with
    |None ->  hds2
    |Some true  -> ("Connection","Keep-Alive")::hds2
    |Some false -> ("Connection","Close")::hds2
  in
  print_endline "avant envoie";
  match code with
    |None -> Xhtml_sender.send ~code:200 ~content:page ~headers:hds3 xhtml_sender
    |Some c -> Xhtml_sender.send ~code:c ~content:page ~headers:hds3
    xhtml_sender
  

(** sends an error page that fit the error number *)
let send_error ?(http_exception) ?(error_num=500) xhtml_sender =
  let (error_code,error_msg) =
    (
      match http_exception with
      |Some (Http_error.Http_exception (code,msgs) )->
          (
            let error_num =
              match code with
              |Some c -> c
              |None -> 500
            in
            let msg =
              Http_error.string_of_http_exception
              (Http_error.Http_exception(code,msgs))
            in (error_num,msg)
          )
          
        |_ ->
           let  error_mes = Http_error.expl_of_code error_num in
           (error_num,error_mes)
     ) in
  let str_code = string_of_int error_code in
        let err_page =
          <<
          <html>
          <h1> Error $str:str_code$ </h1> 
          $str:error_msg$
          </html>
          >>
  in
  send_page ~code:error_code err_page xhtml_sender
(*Xhtml_sender.send ~code:error_code (*~content:err_page*) xhtml_sender*)

(** this fonction create a sender that send http_frame with fiel content*)
let create_file_sender ?server_name ?proto fd =
  let hd =
    match server_name with
    |None -> []
    |Some s -> [("Server",s)]
  in
  let hd2 =
    [
      ("Accept-Ranges","bytes");
      ("Cache-Control","no-cache")
    ]@hd
  in
  match proto with
  |None -> 
      File_sender.create ~headers:hd2 fd
  |Some p ->
      File_sender.create ~headers:hd2 ~proto:p fd

(* send a file in an HTTP frame*)
let send_file ?code ?keep_alive ?cookie file file_sender =
  (*debug*)
  print_endline "d�but send_page";
  (*ajout des option sp�cifique � la page*)
  (*ici il faudrait r�cup�rer la valeur e la commande date*)
  let date = "Tue, 31 May 2006 16:34:59 GMT" in
  (*ici il faudrait r�cup�rer la valeur de la commande uname*)
  let server = "ploplop (Unix) (Gentoo/Linux) omlet"in
  (*il faut r�cup�rer la date de derni�re modification si ca a une
  * signification*)
  let last_mod = "Wed, 20 Oct 1900 12:51:24 GMT" in 
  (*debug*)
  print_endline "avant_hds";
  let hds = 
    [
      ("Date",date);
      ("Last-Modified",last_mod);
    ]
  in
  print_endline "avant hds2";
  let hds2 =
    match cookie with
    |None -> hds
    |Some c -> ("Set-Cookie","session="^c)::hds
  in
  print_endline "avant hds3";
  let hds3 =
    match keep_alive with
    |None ->  hds2
    |Some true  -> ("Connection","Keep-Alive")::hds2
    |Some false -> ("Connection","Close")::hds2
  in
  print_endline "avant envoie";
  match code with
    |None -> File_sender.send ~code:200 ~content:file ~headers:hds3 file_sender
    |Some c -> File_sender.send ~code:c ~content:file ~headers:hds3
    file_sender
  