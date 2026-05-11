#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/themes.sh"

RESET="#[fg=${THEME[foreground]},bg=${THEME[background]},nobold,noitalics,nounderscore,nodim]"

CPU_PERCENT=0
MEM_PERCENT=0

case "$(uname -s)" in
    Linux)
        read -r CPU_LABEL USER NICE SYSTEM IDLE IOWAIT IRQ SOFTIRQ STEAL REST < /proc/stat
        TOTAL=$((USER + NICE + SYSTEM + IDLE + IOWAIT + IRQ + SOFTIRQ + STEAL))
        IDLE_TOTAL=$((IDLE + IOWAIT))
        if [[ $TOTAL -gt 0 ]]; then
            CPU_PERCENT=$(( (TOTAL - IDLE_TOTAL) * 100 / TOTAL ))
        fi

        MEM_TOTAL=$(grep "^MemTotal:" /proc/meminfo | awk '{print $2}')
        MEM_AVAILABLE=$(grep "^MemAvailable:" /proc/meminfo | awk '{print $2}')
        if [[ -n $MEM_TOTAL && $MEM_TOTAL -gt 0 ]]; then
            MEM_PERCENT=$(( (MEM_TOTAL - MEM_AVAILABLE) * 100 / MEM_TOTAL ))
        fi
        ;;
    Darwin)
        TOP_OUTPUT=$(top -l 1 -n 0 2>/dev/null | head -n 5)
        CPU_LINE=$(echo "$TOP_OUTPUT" | grep "^CPU usage:")
        if [[ -n $CPU_LINE ]]; then
            USER_VAL=$(echo "$CPU_LINE" | sed -E 's/.*([0-9]+\.[0-9]+)% user.*/\1/')
            SYS_VAL=$(echo "$CPU_LINE" | sed -E 's/.*([0-9]+\.[0-9]+)% sys.*/\1/')
            if [[ -n $USER_VAL && -n $SYS_VAL ]]; then
                CPU_PERCENT=$(awk "BEGIN {printf(\"%d\", $USER_VAL + $SYS_VAL)}")
            fi
        fi

        VM_OUTPUT=$(vm_stat 2>/dev/null)
        if [[ -n $VM_OUTPUT ]]; then
            PAGES_FREE=$(echo "$VM_OUTPUT" | grep "Pages free:" | sed -E 's/.*: *([0-9]+).*/\1/')
            PAGES_ACTIVE=$(echo "$VM_OUTPUT" | grep "Pages active:" | sed -E 's/.*: *([0-9]+).*/\1/')
            PAGES_INACTIVE=$(echo "$VM_OUTPUT" | grep "Pages inactive:" | sed -E 's/.*: *([0-9]+).*/\1/')
            PAGES_WIRED=$(echo "$VM_OUTPUT" | grep "Pages wired down:" | sed -E 's/.*: *([0-9]+).*/\1/')

            TOTAL_PAGES=$((PAGES_FREE + PAGES_ACTIVE + PAGES_INACTIVE + PAGES_WIRED))
            USED_PAGES=$((PAGES_ACTIVE + PAGES_INACTIVE + PAGES_WIRED))
            if [[ $TOTAL_PAGES -gt 0 ]]; then
                MEM_PERCENT=$(( USED_PAGES * 100 / TOTAL_PAGES ))
            fi
        fi
        ;;
    *)
        CPU_PERCENT=0
        MEM_PERCENT=0
        ;;
esac

CPU_COLOR=${THEME[success]}
if [[ $CPU_PERCENT -ge 80 ]]; then
    CPU_COLOR=${THEME[danger]}
elif [[ $CPU_PERCENT -ge 50 ]]; then
    CPU_COLOR=${THEME[warning]}
fi

MEM_COLOR=${THEME[success]}
if [[ $MEM_PERCENT -ge 80 ]]; then
    MEM_COLOR=${THEME[danger]}
elif [[ $MEM_PERCENT -ge 50 ]]; then
    MEM_COLOR=${THEME[warning]}
fi

echo "${RESET}#[fg=${CPU_COLOR},bg=${THEME[background]},bold]▒ 󰍛 ${CPU_PERCENT}% #[fg=${MEM_COLOR},bg=${THEME[background]},bold]󰘚 ${MEM_PERCENT}%"
