type t = <
  byte       : Lexing.position;
  point_num  : int;
  point_bol  : int;
  file       : string;
  line       : int;

  set_file   : string -> t;
  set_line   : int -> t;
  set_offset : int -> t;
  set        : file:string -> line:int -> offset:int -> t;
  new_line   : string -> t;
  add_nl     : t;

  shift_bytes     : int -> t;
  shift_one_uchar : int -> t;

  offset : [`Byte | `Point] -> int;
  column : [`Byte | `Point] -> int;

  line_offset : [`Byte | `Point] -> int;
  byte_offset : int;

  is_ghost : bool;

  to_string : file:bool -> offsets:bool -> [`Byte | `Point] -> string;
  compact   : file:bool -> offsets:bool -> [`Byte | `Point] -> string
>

type pos = t

(* Constructors *)

let sprintf = Printf.sprintf

let make ~byte ~point_num ~point_bol =
  let () = assert (point_num >= point_bol) in
  object (self)
    val    byte      = byte
    method byte      = byte

    val    point_num = point_num
    method point_num = point_num

    val    point_bol = point_bol
    method point_bol = point_bol

    method set_file file =
      {< byte = Lexing.{byte with pos_fname = file} >}

    method set_line line =
      {< byte = Lexing.{byte with pos_lnum = line} >}

    method set_offset offset =
      {< byte = Lexing.{byte with pos_cnum = byte.pos_bol + offset} >}

    method set ~file ~line ~offset =
      let pos = self#set_file file in
      let pos = pos#set_line line in
      let pos = pos#set_offset offset
      in pos

    method shift_bytes len =
      {< byte = Lexing.{byte with pos_cnum = byte.pos_cnum + len};
         point_num = point_num + len >}

    method shift_one_uchar len =
      {< byte = Lexing.{byte with pos_cnum = byte.pos_cnum + len};
         point_num = point_num + 1 >}

    method add_nl =
      {< byte = Lexing.{byte with
                          pos_lnum = byte.pos_lnum + 1;
                          pos_bol  = byte.pos_cnum};
         point_bol = point_num >}

    (* The string must not contain '\n'. See [add_line]. *)

    method new_line string =
      let len = String.length string
      in (self#shift_bytes len)#add_nl

    method is_ghost = (byte = Lexing.dummy_pos)

    method file = byte.Lexing.pos_fname

    method line = byte.Lexing.pos_lnum

    method offset = function
       `Byte -> Lexing.(byte.pos_cnum - byte.pos_bol)
    | `Point -> point_num - point_bol

    method column mode = 1 + self#offset mode

    method line_offset = function
       `Byte -> byte.Lexing.pos_bol
    | `Point -> point_bol

    method byte_offset = byte.Lexing.pos_cnum

    method to_string ~file ~offsets mode =
      if self#is_ghost then "ghost"
      else
        let offset = self#offset mode in
        let horizontal, value =
          if offsets then
            "character", offset
          else "column", offset + 1 in
        if file && self#file <> "" then
          sprintf "File \"%s\", line %i, %s %i"
                  self#file self#line horizontal value
        else sprintf "Line %i, %s %i"
                     self#line horizontal value

    method compact ~file ~offsets mode =
      if self#is_ghost then "ghost"
      else
        let horizontal =
          if offsets then self#offset mode
          else self#column mode in
        if file && self#file <> "" then
          sprintf "%s:%i:%i" self#file self#line horizontal
        else
          sprintf "%i:%i" self#line horizontal
  end

let from_byte byte =
  let point_num = byte.Lexing.pos_cnum
  and point_bol = byte.Lexing.pos_bol
  in make ~byte ~point_num ~point_bol

let ghost = make ~byte:Lexing.dummy_pos ~point_num:(-1) ~point_bol:(-1)

let min ~file =
  let position = Lexing.{
    pos_fname = file;
    pos_lnum  = 1;
    pos_bol   = 0;
    pos_cnum  = 0} in
  let pos = make ~byte:position ~point_num:0 ~point_bol:0
  in pos#set_file file

let max ~file =
  let position = Lexing.{
    pos_fname = file;
    pos_lnum  = max_int;
    pos_bol   = max_int;
    pos_cnum  = max_int} in
  let pos = make ~byte:position ~point_num:max_int ~point_bol:max_int
  in pos#set_file file

(* Comparisons *)

let equal pos1 pos2 =
  pos1#file = pos2#file && pos1#byte_offset = pos2#byte_offset

let lt pos1 pos2 =
  pos1#file = pos2#file && pos1#byte_offset < pos2#byte_offset

let leq pos1 pos2 = lt pos1 pos2 || equal pos1 pos2

let compare pos1 pos2 =
  if lt pos1 pos2 then -1
  else if lt pos2 pos1 then 1
       else 0

let is_min pos = equal (pos#set_file "") (min ~file:"")

let is_max pos = equal (pos#set_file "") (max ~file:"")
