# Gentoo Check Update
**Скрипт (функция) для ZSH**

---

## 📋 Требования для корректной работы

- **ZSH** - командная оболочка
- **eix** - утилита для поиска пакетов в Gentoo
- **Git** (рекомендуется) - для быстрой синхронизации дерева Portage
- **Qlop** является частью пакета app-portage/portage-utils (набор полезных утилит для работы с Portage).
---
Для установки qlop выполните
```
emerge --ask app-portage/portage-utils
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
Скриншоты

<img width="502" height="437" alt="image" src="https://github.com/user-attachments/assets/f0d436cf-67e6-4b5d-beba-9892ae88a9a6" />

<img width="515" height="298" alt="image" src="https://github.com/user-attachments/assets/4ea548c7-a23b-44cb-bdcc-ed78d6261509" />
