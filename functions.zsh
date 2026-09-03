# ---------------------------------------------------------
# Integracja tmux + ccs (Claude Code Switcher) dla ZSH
# z pełną obsługą iOS (Moshi) oraz bezpiecznym przekazywaniem flag
# ---------------------------------------------------------

# 1. Pobieranie 2 losowych słów z systemowego słownika
# Wynik ląduje w $REPLY, nie na stdout: $RANDOM w podpowłoce $(...) startuje z
# odziedziczonego stanu, więc kolejne wywołania zwracałyby te same słowa.
_cc_get_rand_words() {
    local dict_file="/usr/share/dict/words"

    if [[ -f "$dict_file" ]]; then
        # 1. Pobieramy słowa do zwykłej zmiennej (bez kolizji składniowej wewnątrz ${...})
        local raw_words
        raw_words=$(grep -E '^[a-z]{3,7}$' "$dict_file" 2>/dev/null)

        # 2. Dzielimy wynik po nowych liniach (f) do tablicy Zsh
        local -a words
        words=( ${(f)raw_words} )

        local n=${#words}
        if (( n >= 2 )); then
            local i1 i2
            # $RANDOM ma tylko 15 bitów (0-32767), a słownik jest większy — bez
            # sklejenia dwóch losowań ogon słownika byłby nieosiągalny.
            (( i1 = (RANDOM * 32768 + RANDOM) % n + 1 ))
            (( i2 = (RANDOM * 32768 + RANDOM) % n + 1 ))
            while (( i2 == i1 )); do
                (( i2 = (RANDOM * 32768 + RANDOM) % n + 1 ))
            done
            REPLY="${words[i1]}-${words[i2]}"
            return
        fi
    fi

    REPLY="rand-$(( RANDOM % 899 + 100 ))"
}

# Nazwy sesji tmux nie mogą zawierać kropek ani dwukropków
_cc_sanitize_session_name() {
    echo "${(L)1//[^a-zA-Z0-9_-]/_}"
}

# 2. Główna funkcja orkiestrująca sesje
_cc_launch_session() {
    local profile_prefix="$1"  # 'work' lub 'priv'
    local ccs_base_cmd="$2"     # np. 'ccs w'
    shift 2

    # Smart punctuation zamienia wpisane "--" na pauzę (macOS) albo półpauzę
    # (iOS) — obie muszą wrócić do "--", inaczej getopt widzi klaster krótkich flag.
    local -a normalized_args=()
    local arg
    for arg in "$@"; do
        arg="${arg/#—/--}"
        arg="${arg/#–/--}"
        normalized_args+=( "$arg" )
    done

    local custom_name=""
    local -a ccs_extra_args=()

    if (( ${#normalized_args} > 0 )); then
        if [[ "${normalized_args[1]}" == -* ]]; then
            ccs_extra_args=( "${normalized_args[@]}" )
        else
            custom_name="${normalized_args[1]}"
            ccs_extra_args=( "${(@)normalized_args[2,-1]}" )
        fi
    fi

    local -a cmd=( ${=ccs_base_cmd} "${ccs_extra_args[@]}" )

    # Zagnieżdżenie tmuxa w tmuxie i tak by się nie powiodło — w istniejącej
    # sesji odpalamy ccs wprost w bieżącym panelu.
    if [[ -n "$TMUX" ]]; then
        "${cmd[@]}"
        return
    fi

    # Generowanie nazwy sesji
    local session_name REPLY
    if [[ -n "$custom_name" ]]; then
        local base_name suffix=2
        base_name=$(_cc_sanitize_session_name "${profile_prefix}_${custom_name}")
        session_name="$base_name"
        # tmux new-session -A na istniejącej sesji tylko się podpina i milcząco
        # porzuca polecenie — razem z flagami ccs. Numerujemy aż do wolnej nazwy.
        while tmux has-session -t "=$session_name" 2>/dev/null; do
            session_name="${base_name}-${suffix}"
            (( suffix++ ))
        done
    else
        local dir_name="${PWD:t}"
        # Drugie wywołanie w tym samym katalogu ma dostać własną sesję, a nie
        # przypiąć się do poprzedniej — losujemy aż do wolnej nazwy.
        repeat 20; do
            _cc_get_rand_words
            session_name=$(_cc_sanitize_session_name "${profile_prefix}_${dir_name}-${REPLY}")
            tmux has-session -t "=$session_name" 2>/dev/null || break
        done
    fi

    # Złożenie pełnego polecenia
    # (@qq), nie (q): bez (@) zagnieżdżone rozwinięcie skleja tablicę w skalar i
    # escapuje też spacje między argumentami. Apostrofy przechodzą przez warstwę
    # sh nietknięte, backslashe nie zawsze.
    local full_cmd="${(j: :)${(@qq)cmd}}"

    # KLUCZOWA POPRAWKA:
    # 1. $SHELL -i  -> ładuje ~/.zshrc (dzięki czemu ccs, PATH i NVM są dostępne)
    # 2. || exec $SHELL -> jeśli ccs wywali błąd, sesja NIE zamknie się, lecz zostanie w powłoce, pokazując błąd
    # Serwer tmux narzuca nowym panelom własne cwd — gdy katalog, z którego
    # wystartował, zostanie usunięty, panel dziedziczy martwą ścieżkę i flaga -c
    # tego nie obchodzi. Dlatego wchodzimy do katalogu jawnie już w panelu.
    tmux new-session -A -D -s "$session_name" "$SHELL -i -c \"cd ${(qq)PWD} && $full_cmd || exec $SHELL\""
}

# 3. Interfejsy wywoławcze
ccw() {
    _cc_launch_session "work" "ccs work --dangerously-skip-permissions" "$@"
}

ccp() {
    _cc_launch_session "priv" "ccs personal --dangerously-skip-permissions" "$@"
}

ccm() {
    _cc_launch_session "mm" "ccs mm --dangerously-skip-permissions" "$@"
}

ccz() {
    _cc_launch_session "zai" "ccs zai --dangerously-skip-permissions" "$@"
}

# ---------------------------------------------------------
# Szybkie podłączanie do istniejących sesji tmux
# ---------------------------------------------------------
rc() {
    # Pobieramy listę sesji w formacie: nazwa_sesji|katalog_roboczy
    local sessions_raw
    sessions_raw=$(tmux list-sessions -F "#{session_name}|#{pane_current_path}" 2>/dev/null)

    if [[ -z "$sessions_raw" ]]; then
        echo "Brak aktywnych sesji tmux."
        return 0
    fi

    local -a lines
    lines=( ${(f)sessions_raw} )

    echo "Aktywne sesje tmux:"
    echo "------------------------------------------------------------------"

    local i=1
    local -a session_names
    local line name path

    for line in "${lines[@]}"; do
        name="${line%%|*}"
        path="${line#*|}"

        # Skracamy ścieżkę /Users/twoja_nazwa do ~ dla czytelności na iOS
        path="${path/#$HOME/~}"

        session_names[i]="$name"
        printf " [%2d] %-32s %s\n" "$i" "$name" "($path)"
        (( i++ ))
    done

    echo "------------------------------------------------------------------"
    local choice
    read "choice?Podaj numer sesji (lub Enter aby anulować): "

    # Enter anuluje operację
    if [[ -z "$choice" ]]; then
        echo "Anulowano."
        return 0
    fi

    # Walidacja: czy wpisano cyfrę i czy mieści się w zakresie
    if [[ "$choice" =~ '^[0-9]+$' ]] && (( choice >= 1 && choice <= ${#session_names} )); then
        local target_session="${session_names[choice]}"
        echo "Podłączam do sesji: $target_session..."
        # Flaga -d odłącza ewentualnych innych klientów, dopasowując rozdzielczość do ekranu w Moshi
        tmux attach-session -d -t "$target_session"
    else
        echo "Nieprawidłowy numer sesji."
        return 1
    fi
}

# ---------------------------------------------------------
# Claude Code: pull changes from ~/.claude back into the dotfiles
# ---------------------------------------------------------
ccsync() {
    local src="$HOME/.claude"
    local dest="$DOTFILES/claude"

    if [[ ! -d "$dest" ]]; then
        echo "Brak katalogu $dest"
        return 1
    fi

    # Only files already tracked here: the rest of ~/.claude is session state
    # and artifacts generated by cbm/plugins, which must not land in the repo.
    local -a tracked
    tracked=( ${(f)"$(cd "$dest" && find . -type f ! -name '.DS_Store' | sed 's|^\./||')"} )

    local rel
    for rel in "${tracked[@]}"; do
        if [[ -f "$src/$rel" ]]; then
            cp "$src/$rel" "$dest/$rel"
        else
            echo "Brak w ~/.claude: $rel"
        fi
    done

    git -C "$DOTFILES" status --short claude
}
