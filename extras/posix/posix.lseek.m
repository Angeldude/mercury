%-----------------------------------------------------------------------------%
% vim: ft=mercury ts=4 sw=4 et
%------------------------------------------------------------------------------%
% Copyright (C) 1999, 2005, 2007 The University of Melbourne.
% This file may only be copied under the terms of the GNU Library General
% Public License - see the file COPYING.LIB in the Mercury distribution.
%------------------------------------------------------------------------------%
%
% Module: posix.lseek.m
% Main author: conway@cs.mu.oz.au
%
%------------------------------------------------------------------------------%

:- module posix.lseek.
:- interface.

:- type whence
    --->    set
    ;       cur
    ;       end.

:- pred lseek(fd::in, int::in, lseek.whence::in, posix.result(int)::out,
    io::di, io::uo) is det.

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%

:- implementation.

:- import_module int.

:- pragma foreign_decl("C", "
    #include <sys/types.h>
    #include <unistd.h>
").

%-----------------------------------------------------------------------------%

lseek(Fd, Offset, Whence, Result, !IO) :-
    lseek0(Fd, Offset, Whence, Res, !IO),
    ( Res < 0 ->
        errno(Err, !IO),
        Result = error(Err)
    ;
        Result = ok(Res)
    ).

:- pred lseek0(fd::in, int::in, lseek.whence::in, int::out, io::di, io::uo)
    is det.
:- pragma foreign_proc("C",
    lseek0(Fd::in, Offset::in, Whence::in, Res::out, IO0::di, IO::uo),
    [promise_pure, will_not_call_mercury, thread_safe, tabled_for_io],
"
    Res = lseek(Fd, Offset, Whence);
    IO = IO0;
").

:- pragma foreign_enum("C", lseek.whence/0, [
    set - "SEEK_SET",
    cur - "SEEK_CUR",
    end - "SEEK_END"
]).

%-----------------------------------------------------------------------------%
:- end_module posix.lseek.
%-----------------------------------------------------------------------------%
