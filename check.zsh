#!/bin/zsh

unset TIMEFORMAT

check() {
    local COUNT OUTPUT LOG_FILE="/var/log/portage-update-check.log"
    local DATE=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Цвета для оформления
    local RED='\033[1;31m'
    local GREEN='\033[1;32m'
    local YELLOW='\033[1;33m'
    local BLUE='\033[1;34m'
    local MAGENTA='\033[1;35m'
    local CYAN='\033[1;36m'
    local WHITE='\033[1;37m'
    local BOLD='\033[1m'
    local RESET='\033[0m'
    
    # Символы для оформления
    local CHECK_MARK="✅"
    local WARNING="⚠️"
    local INFO="ℹ️"
    local CLOCK="⏱️"
    local PACKAGE="📦"
    local ROCKET="🚀"
    local PARTY="🎉"
    
    # Функция для вывода разделителя
    separator() {
        echo -e "${CYBOLD}${MAGENTA}════════════════════════════════════════════════════════════${RESET}"
    }
    
    # Функция для вывода заголовка
    header() {
        echo -e "${CYBOLD}${BLUE}$1${RESET}"
    }
    
    # Функция для вывода успешного сообщения
    success() {
        echo -e "${GREEN}${CHECK_MARK} $1${RESET}"
    }
    
    # Функция для вывода предупреждения
    warning() {
        echo -e "${YELLOW}${WARNING} $1${RESET}"
    }
    
    # Функция для вывода информации
    info() {
        echo -e "${CYAN}${INFO} $1${RESET}"
    }
    
    # Создаем лог-файл если не существует
    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE" 2>/dev/null || sudo touch "$LOG_FILE" 2>/dev/null
        chmod 644 "$LOG_FILE" 2>/dev/null || sudo chmod 644 "$LOG_FILE" 2>/dev/null
    fi
    
    echo "[$DATE] Начало проверки обновлений" | tee -a "$LOG_FILE" >/dev/null 2>&1
    
    separator
    header "🔄 ОБНОВЛЕНИЕ БАЗЫ ПАКЕТОВ      "
    separator
    
    # Используем временный файл для полного контроля вывода
    local TEMP_LOG=$(mktemp)
    
    if command -v sudo >/dev/null 2>&1 && [ "$EUID" -ne 0 ]; then
        sudo eix-sync > "$TEMP_LOG" 2>&1
    else
        eix-sync > "$TEMP_LOG" 2>&1
    fi
    
    local SYNC_EXIT_CODE=$?
    
    # Проверяем только код возврата, игнорируем весь вывод
    if [ $SYNC_EXIT_CODE -ne 0 ]; then
        echo -e "${RED}❌ Ошибка при обновлении eix-sync${RESET}" >&2
        echo "[$DATE] Ошибка при обновлении eix-sync" | tee -a "$LOG_FILE" >/dev/null 2>&1
        rm -f "$TEMP_LOG"
        return 1
    fi
    
    # Очищаем временный файл
    rm -f "$TEMP_LOG"
    success "База пакетов успешно обновлена   "
    
    separator
    header "🔍 ПРОВЕРКА ОБНОВЛЕНИЙ     "
    separator
    
    if command -v sudo >/dev/null 2>&1 && [ "$EUID" -ne 0 ]; then
        OUTPUT=$(sudo emerge -pu --deep --newuse @world 2>/dev/null)
    else
        OUTPUT=$(emerge -pu --deep --newuse @world 2>/dev/null)
    fi
    
    COUNT=$(echo "$OUTPUT" | grep -c '^\[.*\] .*-.*\[')
    
    echo "[$DATE] Найдено обновлений: $COUNT" | tee -a "$LOG_FILE" >/dev/null 2>&1
    
    if [ $COUNT -gt 0 ]; then
        separator
        header "${PACKAGE} ДОСТУПНЫЕ ОБНОВЛЕНИЯ"
        separator
        
        echo -e "${YELLOW}Найдено пакетов для обновления: ${BOLD}${COUNT}${RESET}"
        echo
        
        header "📋 СПИСОК ПАКЕТОВ:"
        echo "$OUTPUT" | grep '^\[.*\]' | sed -E 's/^\[[^]]+\] //' | nl -w2 -s'. ' | while read -r line; do
            echo -e "  ${WHITE}${line}${RESET}"
        done
        
        separator
        header "${CLOCK} ОЦЕНКА ВРЕМЕНИ ОБНОВЛЕНИЯ"
#        separator
        
        local TOTAL_SECONDS=0
        local FOUND_COUNT=0
        
        while IFS= read -r pkg_line; do
            pkg_full=$(echo "$pkg_line" | awk '{print $1}')
            pkg_base=$(echo "$pkg_full" | sed -E 's/-[0-9][0-9a-z._-]*$//')
            
            # Получаем время сборки из qlop
            pkg_info=$(qlop "$pkg_base" 2>/dev/null | grep ">>> $pkg_base:" | tail -1)
            
            if [ -n "$pkg_info" ]; then
                pkg_time=$(echo "$pkg_info" | sed -E 's/.*>>> [^:]+: //')
                echo -e "  ${CYAN}${pkg_base}:${RESET} ${WHITE}${pkg_time}${RESET}"
                
                # Конвертируем время в секунды
                if [[ "$pkg_time" =~ ([0-9]+)\'([0-9]+)\" ]]; then
                    minutes=${match[1]}
                    seconds=${match[2]}
                    time_seconds=$((minutes * 60 + seconds))
                elif [[ "$pkg_time" =~ ([0-9]+)s ]]; then
                    time_seconds=${match[1]}
                else
                    time_seconds=0
                fi
                
                if [ $time_seconds -gt 0 ]; then
                    TOTAL_SECONDS=$((TOTAL_SECONDS + time_seconds))
                    FOUND_COUNT=$((FOUND_COUNT + 1))
                fi
            else
                echo -e "  ${CYAN}${pkg_base}:${RESET} ${YELLOW}нет данных${RESET}"
            fi
        done < <(echo "$OUTPUT" | grep '^\[.*\]' | sed -E 's/^\[[^]]+\] //')
        
#        separator
#        header "💡 РЕКОМЕНДАЦИЯ  "
        separator
        
        if [ $FOUND_COUNT -gt 0 ]; then
            local AVG_TIME=$((TOTAL_SECONDS / FOUND_COUNT))
            local ESTIMATED_TOTAL=$((AVG_TIME * COUNT))
            
            echo -e "  ${WHITE}На основе данных ${GREEN}${FOUND_COUNT}${WHITE} из ${GREEN}${COUNT}${WHITE} пакетов${RESET}"
            echo
            
            if [ $ESTIMATED_TOTAL -lt 300 ]; then
                success "Обновление займет менее 5 минут ${ROCKET}"
            elif [ $ESTIMATED_TOTAL -lt 900 ]; then
                info "Обновление займет примерно 5-15 минут"
            elif [ $ESTIMATED_TOTAL -lt 1800 ]; then
                warning "Обновление займет примерно 15-30 минут"
            elif [ $ESTIMATED_TOTAL -lt 3600 ]; then
                warning "Обновление займет примерно 30-60 минут"
            else
                local hours=$((ESTIMATED_TOTAL / 3600))
                local minutes=$(( (ESTIMATED_TOTAL % 3600) / 60 ))
                warning "Обновление займет примерно ${hours}ч ${minutes}м"
                echo -e "  ${YELLOW}Рекомендуется планировать обновление${RESET}"
            fi
        else
            # Резервная оценка по количеству пакетов
            if [ $COUNT -le 3 ]; then
                success "Обновление займет примерно 5-15 минут ${ROCKET}"
            elif [ $COUNT -le 8 ]; then
                info "Обновление займет примерно 15-30 минут"
            elif [ $COUNT -le 15 ]; then
                warning "Обновление займет примерно 30-60 минут"
            else
                warning "Обновление займет более 1 часа"
                echo -e "  ${YELLOW}Рекомендуется планировать обновление${RESET}"
            fi
        fi
        
        separator
#        info "Для установки обновлений выполните: ${WHITE}emerge -u @world${RESET}"
#        separator
        
        # Логируем пакеты
        echo "[$DATE] Пакеты для обновления:" | tee -a "$LOG_FILE" >/dev/null 2>&1
        echo "$OUTPUT" | grep '^\[.*\]' | sed -E 's/^\[[^]]+\] //' | while read -r pkg; do
            echo "  - $pkg" | tee -a "$LOG_FILE" >/dev/null 2>&1
        done
    else
        separator
        header "${PARTY} СТАТУС СИСТЕМЫ"
        separator
        success "Система полностью актуальна!"
        echo
        echo -e " ${GREEN}Все пакеты обновлены до последних версий!${RESET}"
        separator
    fi
    
    local END_DATE=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$END_DATE] Проверка обновлений завершена" | tee -a "$LOG_FILE" >/dev/null 2>&1
}
