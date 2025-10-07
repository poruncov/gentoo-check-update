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
    local GEAR="⚙️"
    
    # Функция для вывода разделителя
    separator() {
        echo -e "${MAGENTA}════════════════════════════════════════════════════════════${RESET}"
    }
    
    # Функция для вывода заголовка
    header() {
        echo -e "${BLUE}${BOLD}$1${RESET}"
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
    
    # Функция для извлечения имени пакета из строки emerge
    extract_package_name() {
        local line="$1"
        # Обрабатываем разные форматы:
        # [ebuild N    ] net-fs/libnfs-5.0.3 USE-"-examples -static-libs -utils™
        # [ebuild R J media-video/vlc-3.@.21_p20250217-r3_USE="nfs*"
        # [ebuild     U] app-admin/eselect-1.4.25 [1.4.24]
        echo "$line" | sed -E 's/^\[[^]]+\]\s+//' | sed -E 's/\s+USE=.*$//' | sed -E 's/\s+\[.*\]$//' | awk '{print $1}'
    }
    
    # Функция для извлечения базового имени пакета (без версии)
    extract_package_base() {
        local pkg_full="$1"
        echo "$pkg_full" | sed -E 's/-[0-9][0-9a-zA-Z._@-]*([-+][0-9a-zA-Z._]+)*$//'
    }
    
    # Создаем лог-файл если не существует
    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE" 2>/dev/null || sudo touch "$LOG_FILE" 2>/dev/null
        chmod 644 "$LOG_FILE" 2>/dev/null || sudo chmod 644 "$LOG_FILE" 2>/dev/null
    fi
    
    echo "[$DATE] Начало проверки обновлений" | tee -a "$LOG_FILE" >/dev/null 2>&1
    
    separator
    header "${GEAR} ОБНОВЛЕНИЕ БАЗЫ ПАКЕТОВ"
    separator
    
    # Используем временный файл для полного контроля вывода
    local TEMP_LOG=$(mktemp)
    
    echo -e "${CYAN}Синхронизация репозиториев...${RESET}"
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
    success "База пакетов успешно обновлена"
    
    separator
    header "🔍 ПРОВЕРКА ОБНОВЛЕНИЙ"
    separator
    
    echo -e "${CYAN}Поиск доступных обновлений...${RESET}"
    if command -v sudo >/dev/null 2>&1 && [ "$EUID" -ne 0 ]; then
        OUTPUT=$(sudo emerge -pu --deep --newuse --changed-use @world 2>/dev/null)
    else
        OUTPUT=$(emerge -pu --deep --newuse --changed-use @world 2>/dev/null)
    fi
    
    # Сохраняем полный вывод для отладки
    local FULL_OUTPUT="$OUTPUT"
    
    # Улучшенный подсчет пакетов - учитываем разные форматы вывода
    COUNT=$(echo "$OUTPUT" | grep -E '^\[.*\]' | grep -v -E '^\[(blocks|update)' | wc -l)
    
    echo "[$DATE] Найдено обновлений: $COUNT" | tee -a "$LOG_FILE" >/dev/null 2>&1
    
    if [ $COUNT -gt 0 ]; then
        separator

        echo -e "${YELLOW}${BOLD}Найдено пакетов для обновления: ${COUNT}${RESET}"
        echo
        
        header "📋 СПИСОК ПАКЕТОВ:"
        local PACKAGE_LIST=""
        local counter=1
        
        
        # Обрабатываем вывод emerge построчно
        while IFS= read -r line; do
            if [[ "$line" =~ ^\[.*\] ]]; then
                # Пропускаем служебные строки
                if [[ "$line" =~ ^\[(blocks|update) ]]; then
                    continue
                fi
                
                pkg_name=$(extract_package_name "$line")
                if [ -n "$pkg_name" ]; then
                    echo -e "  ${WHITE}${counter}. ${pkg_name}${RESET}"
                    PACKAGE_LIST="${PACKAGE_LIST}${pkg_name}\n"
                    counter=$((counter + 1))
                else
                    echo -e "  ${YELLOW}[Ошибка парсинга] ${line}${RESET}" >&2
                fi
            fi
        done <<< "$FULL_OUTPUT"
        
        # Если список пустой, покажем альтернативный способ
        if [ -z "$(echo -e "$PACKAGE_LIST" | tr -d '\n')" ]; then
            # Альтернативный метод извлечения пакетов
           echo "$FULL_OUTPUT" | grep -E '^\[.*\]' | grep -v -E '^\[(blocks|update)' | \
          while IFS= read -r line; do
                # Простой метод - берем все после ] до первого пробела или USE=
                simple_pkg=$(echo "$line" | sed -E 's/^\[[^]]+\]\s+//' | awk '{print $1}' | sed 's/USE=.*//')
                if [ -n "$simple_pkg" ]; then
                    echo -e "  ${WHITE}${counter}. ${simple_pkg}${RESET}"
                    PACKAGE_LIST="${PACKAGE_LIST}${simple_pkg}\n"
                    counter=$((counter + 1))
              fi
            done
        fi
        
        separator
        header "${CLOCK} ОЦЕНКА ВРЕМЕНИ ОБНОВЛЕНИЯ"
        #separator
        
        local TOTAL_SECONDS=0
        local FOUND_COUNT=0
        
        
        # Используем сохраненный список пакетов для анализа
        if [ -n "$PACKAGE_LIST" ]; then
            while IFS= read -r pkg_full; do
                [ -z "$pkg_full" ] && continue
                
                pkg_base=$(extract_package_base "$pkg_full")
                
                # Получаем время сборки из qlop
                pkg_info=$(qlop "$pkg_base" 2>/dev/null | grep ">>> $pkg_base:" | tail -1)
                
                if [ -n "$pkg_info" ]; then
                    pkg_time=$(echo "$pkg_info" | sed -E 's/.*>>> [^:]+: //')
                    echo -e "  ${CYAN}${pkg_base}:${RESET} ${GREEN}${pkg_time}${RESET}"
                    
                    # Конвертируем время в секунды
                    if [[ "$pkg_time" =~ ([0-9]+)\'([0-9]+)\" ]]; then
                        minutes=${match[1]}
                        seconds=${match[2]}
                        time_seconds=$((minutes * 60 + seconds))
                    elif [[ "$pkg_time" =~ ([0-9]+)s ]]; then
                        time_seconds=${match[1]}
                    elif [[ "$pkg_time" =~ ([0-9]+):([0-9]+) ]]; then
                        # Формат MM:SS
                        minutes=${match[1]}
                        seconds=${match[2]}
                        time_seconds=$((minutes * 60 + seconds))
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
            done <<< "$(echo -e "$PACKAGE_LIST")"
        else
            echo -e "  ${YELLOW}Не удалось получить список пакетов для анализа времени${RESET}"
        fi
        
        separator
        
        if [ $FOUND_COUNT -gt 0 ]; then
            local AVG_TIME=$((TOTAL_SECONDS / FOUND_COUNT))
            local ESTIMATED_TOTAL=$((AVG_TIME * COUNT))
            
            echo -e "  ${WHITE}На основе данных ${GREEN}${FOUND_COUNT}${WHITE} из ${GREEN}${COUNT}${WHITE} пакетов${RESET}"
            echo
            
            if [ $ESTIMATED_TOTAL -lt 300 ]; then
                success "Обновление займет менее 5 минут ${ROCKET}"
                echo -e "  ${GREEN}Можно обновлять сразу${RESET}"
            elif [ $ESTIMATED_TOTAL -lt 900 ]; then
                info "Обновление займет примерно 5-15 минут"
                echo -e "  ${CYAN}Подождите завершения процесса${RESET}"
            elif [ $ESTIMATED_TOTAL -lt 1800 ]; then
                warning "Обновление займет примерно 15-30 минут"
                echo -e "  ${YELLOW}Займитесь другими делами${RESET}"
            elif [ $ESTIMATED_TOTAL -lt 3600 ]; then
                warning "Обновление займет примерно 30-60 минут"
                echo -e "  ${YELLOW}Рекомендуется дождаться завершения${RESET}"
            else
                local hours=$((ESTIMATED_TOTAL / 3600))
                local minutes=$(( (ESTIMATED_TOTAL % 3600) / 60 ))
                warning "Обновление займет примерно ${hours}ч ${minutes}м"
                echo -e "  ${YELLOW}Лучше запланировать на удобное время${RESET}"
            fi
        else
            # Резервная оценка по количеству пакетов
            echo -e "  ${WHITE}На основе количества пакетов: ${GREEN}${COUNT}${RESET}"
            echo
            
            if [ $COUNT -le 3 ]; then
                success "Обновление займет примерно 5-15 минут ${ROCKET}"
                echo -e "  ${GREEN}Можно обновлять сразу${RESET}"
            elif [ $COUNT -le 8 ]; then
                info "Обновление займет примерно 15-30 минут"
                echo -e "  ${CYAN}Подождите завершения процесса${RESET}"
            elif [ $COUNT -le 15 ]; then
                warning "Обновление займет примерно 30-60 минут"
                echo -e "  ${YELLOW}Рекомендуется дождаться завершения${RESET}"
            else
                warning "Обновление займет более 1 часа"
                echo -e "  ${YELLOW}Лучше запланировать на удобное время${RESET}"
            fi
        fi
        
        
        # Логируем пакеты
        echo "[$DATE] Пакеты для обновления:" | tee -a "$LOG_FILE" >/dev/null 2>&1
        if [ -n "$PACKAGE_LIST" ]; then
            while IFS= read -r pkg; do
                [ -z "$pkg" ] && continue
                echo "  - $pkg" | tee -a "$LOG_FILE" >/dev/null 2>&1
            done <<< "$(echo -e "$PACKAGE_LIST")"
        else
            echo "  - не удалось извлечь список пакетов" | tee -a "$LOG_FILE" >/dev/null 2>&1
        fi
    else
        separator
        header "${PARTY} СТАТУС СИСТЕМЫ"
        separator
        success "Система полностью актуальна!"
        echo
        echo -e "  ${GREEN}Все пакеты обновлены до последних версий!${RESET}"
        echo -e "  ${CYAN}Проверка завершена успешно ${CHECK_MARK}${RESET}"
    fi
    
    separator
    local END_DATE=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$END_DATE] Проверка обновлений завершена" | tee -a "$LOG_FILE" >/dev/null 2>&1
}
