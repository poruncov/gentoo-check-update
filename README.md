# Gentoo Check Update
**Скрипт (функция) для ZSH**

---

## 📋 Требования для корректной работы

- **ZSH** - командная оболочка
- **eix** - утилита для поиска пакетов в Gentoo
- **Git** (рекомендуется) - для быстрой синхронизации дерева Portage
- **Qlop** является частью пакета app-portage/portage-utils (набор полезных утилит для работы с Portage).
---
Для установки qlop и eix выполните
```
emerge --ask app-portage/portage-utils app-portage/eix
```
---

## ⚙️ Настройка Git-синхронизации Portage

### Создание конфигурационного файла:

sudo nano /etc/portage/repos.conf/gentoo.conf
```
[DEFAULT]
main-repo = gentoo

[gentoo]
location = /var/db/repos/gentoo
sync-type = git
sync-uri = https://github.com/gentoo-mirror/gentoo.git
auto-sync = yes
priority = 50
```
---
⚠️ Важное примечание:
Перед первым запуском убедитесь, что директория /var/db/repos/gentoo пуста. 
```
sudo ls -lha /var/db/repos/gentoo
```
### Для очистки каталога выполните
```
rm -Rf /var/db/repos/gentoo/*
```
В противном случае при синхронизации произойдет ошибка.
---
🚀 Установка и запуск
Пошаговая установка:

# 1. Переход во временную директорию
```
cd /tmp
```
# 2. Клонирование репозитория
```
git clone https://github.com/poruncov/gentoo-check-update.git
```
# 3. Установка прав выполнения
```
chmod +x install.sh
```
# 4. Запуск установки
```
./install.sh
```
# Удаление временных файлов
```
rm -Rf /tmp/gentoo-check-update/
```
🔧 Особенности

✅ Оптимизированная работа с Git-синхронизацией

✅ Расширенная функциональность по сравнению со стандартными инструментами

✅ Интеграция с ZSH для удобного использования

✅ Быстрая проверка обновлений пакетов
---
Скриншот
<img width="500" height="594" alt="image" src="https://github.com/user-attachments/assets/813b0b6a-602e-47d5-8f44-f5e154a5e572" />

