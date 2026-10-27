:- module(praxo_bridge, [main/0]).

:- initialization(main, main).

main :-
    current_prolog_flag(argv, Arguments),
    command(Command, CommandArguments),
    append(CommandArguments, Arguments, AllArguments),
    catch(
        run_bridge(Command, AllArguments),
        Error,
        ( format(user_error, "Cannot start praxo-bridge: ~w~n", [Error]),
          halt(1)
        )
    ).

command(Command, Arguments) :-
    ( catch(getenv('PRAXO_BRIDGE_BIN', Binary), _, fail),
      Binary \== ''
    ->
        Command = Binary,
        Arguments = []
    ;
        Command = go,
        Arguments = ['run', './cmd/praxo-bridge']
    ).

run_bridge(Command, Arguments) :-
    process_create(
        Command,
        Arguments,
        [ stdin(pipe(Input)),
          stdout(pipe(Output)),
          stderr(pipe(Diagnostics)),
          process(Pid)
        ]
    ),
    set_stream(Input, encoding(utf8)),
    set_stream(Output, encoding(utf8)),
    set_stream(Diagnostics, encoding(utf8)),
    set_stream(user_input, encoding(utf8)),
    set_stream(user_output, encoding(utf8)),
    set_stream(user_error, encoding(utf8)),
    read_all(user_input, Payload),
    format(Input, "~s", [Payload]),
    flush_output(Input),
    close(Input),
    read_all(Output, StandardOutput),
    close(Output),
    read_all(Diagnostics, StandardError),
    close(Diagnostics),
    process_wait(Pid, Status),
    format(user_output, "~s", [StandardOutput]),
    flush_output(user_output),
    format(user_error, "~s", [StandardError]),
    flush_output(user_error),
    exit_status(Status).

read_all(Stream, String) :-
    read_codes(Stream, [], Reversed),
    reverse(Reversed, Codes),
    string_codes(String, Codes).

read_codes(Stream, Accumulator, Codes) :-
    get_char(Stream, Character),
    ( Character == end_of_file
    -> Codes = Accumulator
    ;  read_codes(Stream, [Character | Accumulator], Codes)
    ).

exit_status(exit(Code)) :-
    !,
    halt(Code).
exit_status(_) :-
    halt(1).
