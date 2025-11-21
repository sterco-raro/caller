function caller --argument-names cmd --description "Contact remote host through configured SSH connection (~/.ssh/config)"
    set --local caller_version 0.1.0
    set --local caller_version_description "First draft"

    set --global _caller_is_kitty_terminal false

    switch "$cmd"
        case -v --version
            echo "caller, version $caller_version: $caller_version_description"

        case "" -h --help
            echo "Usage: caller connect             Try to connect to host using SSH"
            echo "       caller list                List configured SSH connections in ~/.ssh/config"
            echo "Options:"
            echo "       -v, --version              Print version"
            echo "       -h, --help                 Print this help message"
            echo "Variables:"
            echo "       _caller_is_kitty_terminal  Whether the current terminal is a Kitty instance"
            echo "Examples:"
            echo "       caller connect remote-host-name"

        case connect
            set --local target_host "$argv[2]"

            if string match --quiet -- "xterm-kitty" "$TERM"
                set --global _caller_is_kitty_terminal true
            end

            # TODO 1: one argument given, if is ~/.ssh/config host try to connect, else either throw error or try host with user root
            # TODO 2: two arguments given, try to connect using first one as user and second one as host. If successful, ask to save configuration (backup old config, append block)?
            # TODO 3: otherwise, create a new command to save configs, like "connect create <user> <host>" or "connect new <user> <host>"

            if test "$target_host" = ""
                echo "caller: Not enough arguments for command: \"$cmd\"" >&2 && return 1
            end

            # Test if the given host is present in the SSH configuration
            if not string match --quiet -- "$target_host" (cat ~/.ssh/config | ag ^Host | cut -d" " -f2)
                echo "caller: Unknown host" >&2 && return 2
            end

            # Connect to host
            if test "$_caller_is_kitty_terminal" = true
                set --export TERM "xterm"
            end

            ssh "$target_host"

            if test "$_caller_is_kitty_terminal" = true
                set --export TERM "xterm-kitty"
            end

        case list
            cat ~/.ssh/config | ag ^Host | cut -d" " -f2

        case \*
            echo "caller: Unknown command: \"$cmd\"" >&2 && return 1
    end
end

function on_destroy_connection --on-event fish_postexec
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
