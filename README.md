# Prism

**Prism** — веб-менеджер WireGuard / AWG туннелей для роутеров Keenetic.

> Проект **не аффилирован** ни с одним VPN-проектом, разрабатывается и поддерживается независимо.

## Возможности

- Управление туннелями через браузер — создание, удаление, запуск, остановка
- Поддержка WireGuard и AWG 2.0 (kernel mode)
- Интеграция с Keenetic — интерфейс регистрируется в NDMS для настройки маршрутизации
- Каталог доменов для маршрутизации (источник: [v2fly/domain-list-community](https://github.com/v2fly/domain-list-community))
- Статистика трафика по каждому пиру в реальном времени
- JWT-авторизация (логин / пароль)
- Liquid Glass UI
- Один статический бинарь (~8 МБ), без зависимостей
- Автозапуск туннелей при старте роутера
- Мультиархитектурность: mipsel, mips, arm64, amd64

## Требования

- Роутер Keenetic с установленным [Entware](https://help.keenetic.com/hc/ru/articles/360021888880)
- Модуль ядра AWG / WireGuard
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

## Сборка из исходников

```sh
git clone https://github.com/bolt109g/prism
cd prism
./scripts/build.sh
```

Бинари появятся в `./dist/`:
| Файл | Платформа |
|------|-----------|
| `prism-linux-mipsel` | Keenetic MIPSEL |
| `prism-linux-mips` | Keenetic MIPS |
| `prism-linux-arm64` | Keenetic AARCH64 |
| `prism-linux-amd64` | x86_64 (для тестов) |

## API

<details>
<summary>Полный список эндпоинтов</summary>

### Публичные
| Метод | Путь | Описание |
|-------|------|----------|
| `POST` | `/api/auth/login` | Получить JWT-токен |
| `GET` | `/api/health` | Статус сервиса |

### Требуют авторизации (Bearer JWT)
| Метод | Путь | Описание |
|-------|------|----------|
| `GET` | `/api/tunnels` | Список туннелей |
| `POST` | `/api/tunnels` | Создать туннель |
| `GET` | `/api/tunnels/:name` | Детали туннеля |
| `DELETE` | `/api/tunnels/:name` | Удалить туннель |
| `POST` | `/api/tunnels/:name/up` | Поднять туннель |
| `POST` | `/api/tunnels/:name/down` | Опустить туннель |
| `POST` | `/api/tunnels/:name/restart` | Перезапустить |
| `GET` | `/api/tunnels/:name/stats` | Статистика трафика |
| `GET` | `/api/tunnels/:name/policy` | Политика маршрутизации |
| `PUT` | `/api/tunnels/:name/policy` | Обновить политику |
| `GET` | `/api/tunnels/next-name` | Следующее имя awgN |
| `GET` | `/api/services` | Каталог сервисов с доменами |
| `POST` | `/api/services/refresh` | Обновить списки доменов |
| `GET` | `/api/log` | Последние 200 строк лога |
| `GET` | `/api/system` | Информация о системе |
| `POST` | `/api/auth/change-password` | Сменить пароль |

</details>

## Структура проекта

```
prism/
├── main.go              # HTTP-сервер, embed UI, graceful shutdown
├── awg/                 # Парсер конфигов, управление туннелями через awg-quick
├── api/                 # REST API обработчики, JWT-авторизация
├── store/               # Хранилище метаданных (JSON)
├── policy/              # Каталог сервисов, загрузка доменов из v2fly
├── web/static/          # Встроенный веб-интерфейс
└── scripts/             # Установка, сборка, init.d
```

## Лицензия

MIT
