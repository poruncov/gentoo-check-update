#!/bin/zsh

unset TIMEFORMAT

check() {
    local COUNT OUTPUT LOG_FILE="/var/log/portage-update-check.log"
    local DATE=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Создаем лог-файл если не существует
    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE" 2>/dev/null || sudo touch "$LOG_FILE" 2>/dev/null
        chmod 644 "$LOG_FILE" 2>/dev/null || sudo chmod 644 "$LOG_FILE" 2>/dev/null
    fi
    
    echo "[$DATE] Начало проверки обновлений" | tee -a "$LOG_FILE" >/dev/null 2>&1
    
    # Функция для вывода в рамке
    print_in_box() {
        local text="$1"
        echo "┌────────────────────────────────────────────────────┐"
        echo "│ $text"
        echo "└────────────────────────────────────────────────────┘"
    }
    
    # Функция для вывода многострочного текста в рамке
    print_multiline_in_box() {
        while IFS= read -r line; do
            if [ -z "$line" ]; then
                echo "│"
            else
                printf "│ %-54s \n" "$line"
            fi
        done <<< "$1"
    }
    
    # Начало общей рамки
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║                 ПРОВЕРКА ОБНОВЛЕНИЙ                    ║"
    echo "╟────────────────────────────────────────────────────────╢"
    echo "║                                                        ║"
    echo "║                 Пожалуйста подождите...                ║"
    echo "║                                                        ║"
    echo "╟────────────────────────────────────────────────────────╢"    
    
    # Обновление базы пакетов (без вывода)
    local TEMP_LOG=$(mktemp)
    if command -v sudo >/dev/null 2>&1 && [ "$EUID" -ne 0 ]; then
    { time (sudo eix-sync -q > "$TEMP_LOG" 2>&1); } 2>/dev/null      
    else
        eix-sync > "$TEMP_LOG" 2>&1
    fi
    rm -f "$TEMP_LOG"
    
    # Проверка обновлений
    if command -v sudo >/dev/null 2>&1 && [ "$EUID" -ne 0 ]; then
        OUTPUT=$(sudo emerge -pu --deep --newuse --changed-use @world 2>/dev/null)
    else
        OUTPUT=$(emerge -pu --deep --newuse --changed-use @world 2>/dev/null)
    fi
    
    local FULL_OUTPUT="$OUTPUT"
    COUNT=$(echo "$OUTPUT" | grep -E '^\[.*\]' | grep -v -E '^\[(blocks|update)' | wc -l)
    
    echo "[$DATE] Найдено обновлений: $COUNT" | tee -a "$LOG_FILE" >/dev/null 2>&1
    
    if [ $COUNT -gt 0 ]; then
        echo "║                                                        ║"
        echo "║                 ДОСТУПНЫЕ ОБНОВЛЕНИЯ                   ║"
        echo "║                                                        ║"
        echo "║   Найдено пакетов для обновления: $COUNT                    ║"
        echo "╟────────────────────────────────────────────────────────╢"
        echo "║                                                        ║"
        echo "║                   СПИСОК ПАКЕТОВ                       ║"
        echo "║                                                        ║"
        
        local PACKAGE_LIST=$(echo "$FULL_OUTPUT" | grep -E '^\[.*\]' | grep -v -E '^\[(blocks|update)' | \
            sed -E 's/^\[[^]]+\]\s+//' | awk '{print $1}' | sed 's/USE=.*//')
        
        local counter=1
        if [ -n "$PACKAGE_LIST" ]; then
            while IFS= read -r pkg_name; do
                [ -z "$pkg_name" ] && continue
                printf "║ %2d. %-51s║\n" $counter "$pkg_name"
                counter=$((counter + 1))
            done <<< "$PACKAGE_LIST"
        fi
        echo "╟────────────────────────────────────────────────────────╢"
        echo "║                                                        ║"
        echo "║              ОЦЕНКА ВРЕМЕНИ ОБНОВЛЕНИЯ                 ║"
        echo "║                                                        ║"
        echo "║ Анализ времени сборки пакетов...                       ║"
        echo "║                                                        ║"
        
        local TOTAL_SECONDS=0
        local FOUND_COUNT=0
        
        if [ -n "$PACKAGE_LIST" ]; then
            while IFS= read -r pkg_full; do
                [ -z "$pkg_full" ] && continue
                
                pkg_base=$(echo "$pkg_full" | sed -E 's/-[0-9][0-9a-zA-Z._@-]*([-+][0-9a-zA-Z._]+)*$//')
                pkg_info=$(qlop "$pkg_base" 2>/dev/null | grep ">>> $pkg_base:" | tail -1)
                
                if [ -n "$pkg_info" ]; then
                    pkg_time=$(echo "$pkg_info" | sed -E 's/.*>>> [^:]+: //')
                    printf "║ %-35s %-18s ║\n" "$pkg_base:" "$pkg_time"
                    
                    local time_seconds=0
                    if [[ "$pkg_time" =~ ([0-9]+)[\'′]?([0-9]+)[\"]? ]]; then
                        minutes=${match[1]}
                        seconds=${match[2]}
                        time_seconds=$((minutes * 60 + seconds))
                    elif [[ "$pkg_time" =~ ([0-9]+)s ]]; then
                        time_seconds=${match[1]}
                    elif [[ "$pkg_time" =~ ([0-9]+):([0-9]+) ]]; then
                        minutes=${match[1]}
                        seconds=${match[2]}
                        time_seconds=$((minutes * 60 + seconds))
                    fi
                    
                    if [ $time_seconds -gt 0 ]; then
                        TOTAL_SECONDS=$((TOTAL_SECONDS + time_seconds))
                        FOUND_COUNT=$((FOUND_COUNT + 1))
                    fi
                fi
            done <<< "$PACKAGE_LIST"
        fi
        
                echo "╟────────────────────────────────────────────────────────╢"
                echo "║                                                        ║"
        
        if [ $FOUND_COUNT -gt 0 ]; then
            local AVG_TIME=$((TOTAL_SECONDS / FOUND_COUNT))
            local ESTIMATED_TOTAL=$((AVG_TIME * COUNT))
            
            if [ $ESTIMATED_TOTAL -lt 300 ]; then
                echo "║ Обновление займет менее 5 минут                        ║"
            elif [ $ESTIMATED_TOTAL -lt 900 ]; then
                echo "║ Обновление займет примерно 5-15 минут                  ║"
            elif [ $ESTIMATED_TOTAL -lt 1800 ]; then
                echo "║ Обновление займет примерно 15-30 минут                 ║"
            elif [ $ESTIMATED_TOTAL -lt 3600 ]; then
                echo "║ Обновление займет примерно 30-60 минут                 ║"
            else
                local hours=$((ESTIMATED_TOTAL / 3600))
                local minutes=$(( (ESTIMATED_TOTAL % 3600) / 60 ))
                printf "║ Обновление займет примерно %2dч %2dм                      ║\n" $hours $minutes
            fi
        else
            if [ $COUNT -le 3 ]; then
                echo "║ Обновление займет примерно 5-15 минут                  ║"
            elif [ $COUNT -le 8 ]; then
                echo "║ Обновление займет примерно 15-30 минут                 ║"
            elif [ $COUNT -le 15 ]; then
                echo "║ Обновление займет примерно 30-60 минут                 ║"
            else
                echo "║ Обновление займет более 1 часа                         ║"
            fi
        fi
        
        # Логируем пакеты
        echo "[$DATE] Пакеты для обновления:" | tee -a "$LOG_FILE" >/dev/null 2>&1
        if [ -n "$PACKAGE_LIST" ]; then
            while IFS= read -r pkg; do
                [ -z "$pkg" ] && continue
                echo "  - $pkg" | tee -a "$LOG_FILE" >/dev/null 2>&1
            done <<< "$PACKAGE_LIST"
        fi
    else
        echo "║                                                        ║"
        echo "║             Система полностью актуальна!               ║"
        echo "║                                                        ║"
    fi
    
    # Закрытие общей рамки
    echo "║                                                        ║"
    echo "╚════════════════════════════════════════════════════════╝"
    
    local END_DATE=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$END_DATE] Проверка обновлений завершена" | tee -a "$LOG_FILE" >/dev/null 2>&1
}
