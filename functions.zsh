arm() {
  arch -x86_64 $@
}

# --- DTACH & CLAUDE CODE ZARZĄDZANIE ---

# Pomocnicza funkcja generująca unikalny slug
_cc_slug() {
    local adjs=(cyber neon pixel smart swift bold calm wild dark hyper solid flux nova azure)
    local nouns=(fox owl hawk lynx node core byte wave spark star wolf bear nexus)
    echo "${adjs[$RANDOM % ${#adjs[@]} + 1]}_${nouns[$RANDOM % ${#nouns[@]} + 1]}_$((RANDOM % 900 + 100))"
}

# Główny, ukryty silnik (przyjmuje tryb ccs jako pierwszy argument)
_cc_engine() {
    local cc_mode="$1" # 'work' lub 'personal'
    shift

    local session_name=""
    if [[ -n "$1" && "$1" != -* ]]; then
        session_name="$1"
        shift
    else
        session_name=$(_cc_slug)
    fi

    local socket_path="/tmp/dtach_claude_${session_name}.sock"

    echo "Pobudzanie sesji dtach: $session_name (Tryb: $cc_mode)"
    echo "Pamiętaj: Aby odpiąć sesję i wyjść (zostawiając proces w tle), wciśnij Ctrl + X"

    # Przekazujemy argumenty bezpośrednio, z pominięciem klejenia stringów.
    # "claude-session" służy jako $0 dla nowej powłoki, by "$@" mogło rozwinąć się w $1, $2...
    dtach -A "$socket_path" -e '^x' zsh -ic "ccs $cc_mode --dangerously-skip-permissions \"\$@\"; exec zsh" "claude-session" "$@"
}

# 1. Domyślne wywołanie (bez przedrostka, odpala tryb work)
ccr() {
    _cc_engine "work" "$@"
}

# 2. Wrapper dla pracy (przedrostek work_, tryb work)
ccw() {
    local suffix=""
    if [[ -n "$1" && "$1" != -* ]]; then
        suffix="$1"
        shift
    else
        suffix=$(_cc_slug)
    fi
    _cc_engine "work" "work_${suffix}" "$@"
}

# 3. Wrapper dla projektów prywatnych (przedrostek priv_, tryb personal)
ccp() {
    local suffix=""
    if [[ -n "$1" && "$1" != -* ]]; then
        suffix="$1"
        shift
    else
        suffix=$(_cc_slug)
    fi
    _cc_engine "personal" "priv_${suffix}" "$@"
}

# 4. Interaktywne menu dla ISTNIEJĄCYCH sesji
# Interaktywne menu wyboru sesji z podglądem ścieżek
rc() {
    local sockets=(/tmp/dtach_claude_*.sock(N))

    if [[ ${#sockets[@]} -eq 0 ]]; then
        echo "Brak aktywnych sesji."
        return
    fi

    echo "Aktywne sesje Claude:"
    local session_names=()
    local i=1

    for sock in $sockets; do
        # Wyciąganie samej nazwy sesji z pliku
        local filename=${sock:t}
        local name=${filename#dtach_claude_}
        name=${name%.sock}

        session_names+=("$name")

        # Domyślny fallback, gdyby lsof nie mógł odczytać procesu
        local cwd_path="[nieznany katalog]"

        # 1. Pobieramy PID procesu, który obsługuje ten socket (dtach master)
        local pid=$(lsof -t "$sock" 2>/dev/null | head -n 1)

        if [[ -n "$pid" ]]; then
            # 2. Odpytujemy lsof o katalog roboczy (cwd) dla tego konkretnego PID-u
            # Flaga -n zapobiega rozwiązywaniu DNS (przyspiesza działanie)
            # Flaga -Fn zwraca łatwe do sparsowania wyjście (szukamy linii zaczynającej się od 'n')
            local raw_cwd=$(lsof -a -p "$pid" -d cwd -n -Fn 2>/dev/null | awk '/^n/ {print substr($0, 2)}')

            if [[ -n "$raw_cwd" ]]; then
                # Zamiana /Users/mateusz na ~ dla lepszej czytelności w menu
                cwd_path=${raw_cwd/#$HOME/\~}
            fi
        fi

        echo "  $i) $name"
        echo "     └─ $cwd_path"
        ((i++))
    done

    echo ""
    read "choice?Wybierz numer sesji (lub wciśnij Enter, aby anulować): "

    if [[ -z "$choice" ]]; then
        echo "Anulowano."
        return
    fi

    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt ${#session_names[@]} ]]; then
        echo "Nieprawidłowy wybór."
        return
    fi

    local selected_name=${session_names[$choice]}
    local socket_path="/tmp/dtach_claude_${selected_name}.sock"

    echo ""
    echo "Podłączanie do sesji: $selected_name"
    echo "Pamiętaj: Aby odpiąć sesję i wyjść (zostawiając proces w tle), wciśnij Ctrl + X"

    dtach -a "$socket_path" -e '^x'
}

# # Listing aktywnych sesji
rl() {
    echo "Aktywne sesje Claude:"

    # Pobranie listy plików gniazd (flaga (N) zapobiega błędom zsh, gdy brak plików)
    local sockets=(/tmp/dtach_claude_*.sock(N))

    if [[ ${#sockets[@]} -eq 0 ]]; then
        echo "  Brak aktywnych sesji."
        return
    fi

    for sock in $sockets; do
        # Natywne wyciąganie samej nazwy sesji ze ścieżki pliku (szybkie operacje na stringach zsh)
        local filename=${sock:t}
        local name=${filename#dtach_claude_}
        name=${name%.sock}

        echo "  🟢 $name"
    done
}
