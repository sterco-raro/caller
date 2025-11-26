function caller --description "Connect to configured SSH hosts"
    set --local caller_version 0.1.0
    set --local caller_version_description "First draft"

    argparse --name "caller" --stop-nonopt "h/help" "v/version" -- $argv
    or return

    if set --query _flag_version
        printf %s\n "caller, version $caller_version: $caller_version_description"
    else if set --query _flag_help
        _caller_help
    else if functions --query _caller_sub_$argv[1]
        _caller_sub_$argv[1] $argv[2..]
    else
        _caller_help
        return 1
    end
end

function _caller_help
    printf %s\n \
        "Usage: caller [options] subcommand [options]" \
        "" \
        "Options:" \
        "   -v, --version   print installed version" \
        "   -h, --help      print this help message" \
        "" \
        "Subcommands" \
        "   add        configure a new connection" \
        "   connect    try to connect to a host using SSH configs" \
        "   list       list configured connections in ~/.ssh/config" \
        "" \
        "Variables:" \
        "   _caller_is_kitty_terminal    whether the current terminal is a Kitty instance" \
        "" \
        "Examples:" \
        "   caller connect my-cute-server"
end

function _caller_sub_add

    set --local options c/compression i/identity-file= l/log-level= p/port= u/user=
    argparse $options -- $argv

    printf %s\n "_flag_compression: $_flag_compression"
    printf %s\n "_flag_identity_file: $_flag_identity_file"
    printf %s\n "_flag_log_level: $_flag_log_level"
    printf %s\n "_flag_port: $_flag_port"
    printf %s\n "_flag_user: $_flag_user"
    printf %s\n "argv: $argv"
    printf %s\n "argv_opts: $argv_opts"

end

function _caller_sub_connect --argument-names target_host
    argparse --name "caller: connect" -- "$argv"
    or return

    if test "$target_host" = ""
        _caller_help
        return 1
    end

    if string match --quiet -- "xterm-kitty" "$TERM"
        set --global _caller_is_kitty_terminal true
    end

    # TODO 1: one argument given, if is ~/.ssh/config host try to connect, else either throw error or try host with user root
    # TODO 2: two arguments given, try to connect using first one as user and second one as host. If successful, ask to save configuration (backup old config, append block)?
    # TODO 3: otherwise, create a new command to save configs, like "connect create <user> <host>" or "connect new <user> <host>"
    # TODO 4: avoid duplicates when creating a new config line

    # Test if the given host is present in the SSH configuration
    if not string match --quiet -- "$target_host" (caller list)
        echo "caller: unknown host" >&2 && return 2
    end

    # Connect to host
    if test "$_caller_is_kitty_terminal" = true
        set --export TERM "xterm"
    end

    ssh "$target_host"

    if test "$_caller_is_kitty_terminal" = true
        set --export TERM "xterm-kitty"
    end
end

function _caller_sub_list
    argparse --name "caller: list" -- "$argv"
    or return

    printf %s\n (awk -F' ' '/^Host/ && !/ \*/ {print $2}' ~/.ssh/config)
end

function _caller_on_destroy_connection --on-event fish_postexec
    set --local exit_status "$status"

    # TODO I don't know how to remove this event listener after its execution
    if not string match --quiet -- "caller" (echo "$argv[1]" | cut -d" " -f1)
        return
    end

    # SIGINT == 130, SIGQUIT == 131
    if test "$exit_status" -eq 130 || test "$exit_status" -eq 131
        if test "$_caller_is_kitty_terminal" = true
            set --export TERM "xterm-kitty"
        end
    end
end
