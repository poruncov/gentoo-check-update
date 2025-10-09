#!/bin/zsh

update-time() {
    sed 's/^ *//' /var/log/update.log | awk '
        function fix_encoding(str) {
            # Исправляем распространенные проблемы с кодировкой
            gsub(/Bc/, "Вс", str)
            gsub(/C0/, "Сб", str)
            gsub(/Cp/, "Ср", str)
            gsub(/Map/, "Мар", str)
            gsub(/amp/, "апр", str)
            gsub(/Man/, "Май", str)
            gsub(/MM/, "Июн", str)
            gsub(/MM/, "Июл", str)
            gsub(/авт/, "авг", str)
            gsub(/Thu/, "Чт", str)
            return str
        }

        function parse_russian_date(date_str) {
            date_str = fix_encoding(date_str)
            gsub(/ янв /, " Jan ", date_str)
            gsub(/ фев /, " Feb ", date_str)
            gsub(/ мар /, " Mar ", date_str)
            gsub(/ апр /, " Apr ", date_str)
            gsub(/ май /, " May ", date_str)
            gsub(/ июн /, " Jun ", date_str)
            gsub(/ июл /, " Jul ", date_str)
            gsub(/ авг /, " Aug ", date_str)
            gsub(/ сен /, " Sep ", date_str)
            gsub(/ окт /, " Oct ", date_str)
            gsub(/ ноя /, " Nov ", date_str)
            gsub(/ дек /, " Dec ", date_str)
            gsub(/^Пн |^Вт |^Ср |^Чт |^Пт |^Сб |^Вс /, "", date_str)
            gsub(/^Mon |^Tue |^Wed |^Thu |^Fri |^Sat |^Sun /, "", date_str)
            return date_str
        }

        BEGIN { 
            print "╔════════════════════════════════════ История обновлений ══════════════════════════════════════════╗"
        }

        /^start / { 
            start_line = fix_encoding($0)
            start_time = substr($0, index($0,$2))
            start_time_eng = parse_russian_date(start_time)
            next 
        }

        /^stop / { 
            if (start_line != "") {
                stop_line = fix_encoding($0)
                stop_time = substr($0, index($0,$2))
                stop_time_eng = parse_russian_date(stop_time)

                # Для отладки - покажем что парсим
                # print "DEBUG start:", start_time_eng > "/dev/stderr"
                # print "DEBUG stop:", stop_time_eng > "/dev/stderr"

                start_cmd = "date -d \"" start_time_eng "\" +%s 2>/dev/null"
                stop_cmd = "date -d \"" stop_time_eng "\" +%s 2>/dev/null"

                start_cmd | getline start_ts; close(start_cmd)
                stop_cmd | getline stop_ts; close(stop_cmd)

                if (start_ts != "" && stop_ts != "" && stop_ts > start_ts) {
                    duration = stop_ts - start_ts
                    if (duration >= 3600) {
                        time_str = sprintf("⏱ %02d:%02d:%02d", int(duration/3600), int((duration%3600)/60), duration%60)
                    } else {
                        time_str = sprintf("⏱ %02d:%02d", int(duration/60), duration%60)
                    }
                } else {
                    time_str = "⏱ ??:??"
                }

                printf "║ %-80s %-15s ║\n", start_line " → " stop_line, time_str
                start_line = ""
            }
        }

        END {
            print "╚══════════════════════════════════════════════════════════════════════════════════════════════════╝"
        }
    '
}
