# Prism

**Prism** — веб-менеджер WireGuard / AWG туннелей для роутеров Keenetic.

## Возможности

- Управление туннелями через браузер — создание, удаление, запуск, остановка
- Поддержка WireGuard и AWG 2.0 (kernel mode)
- Интеграция с Keenetic — интерфейс регистрируется в NDMS для настройки маршрутизации
- Каталог доменов для маршрутизации
- Статистика трафика в реальном времени
- Авторизация (логин / пароль)
- Один бинарь (~6 МБ), без зависимостей
- Автозапуск туннелей при старте роутера
- Архитектуры: mipsel, mips, arm64, amd64

## Требования

- Роутер Keenetic с установленным [Entware](https://help.keenetic.com/hc/ru/articles/360021888880)
- Модуль ядра AWG или WireGuard
- Утилита `awg-quick` или `wg-quick`

## Установка

```sh
curl -sL https://raw.githubusercontent.com/bolt109g/prism/main/scripts/install.sh | sh
```

Установка конкретной версии:
```sh
curl -sL https://raw.githubusercontent.com/bolt109g/prism/main/scripts/install.sh | sh -s -- 1.0.0
```

## Удаление

```sh
/opt/etc/init.d/S99prism stop
rm -f /opt/bin/prism /opt/etc/init.d/S99prism
rm -rf /opt/etc/prism
```

## Учётные данные по умолчанию

```
Логин:  admin
Пароль: admin
```

**Смените пароль после первого входа!**

## Лицензия

MIT
