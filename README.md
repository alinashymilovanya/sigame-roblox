# SIGame Lounge — Roblox

Мультяшная lounge-версия SIGame для компании: ведущий сидит во главе стола, игроки заходят со своих устройств, выбирают вопросы, отвечают и могут шутливо взаимодействовать между ходами.

## Что уже зафиксировано

- классическое поле SIGame с категориями и стоимостью вопросов;
- один постоянный ведущий на сервере;
- от 2 игроков плюс ведущий;
- индивидуальные ответы: текст, карточки вариантов и быстрые кнопки;
- каталог паков внутри игры с поиском, фильтрами и установкой из Steam Workshop;
- загрузка исходного `.siq` без ручной подготовки пользователем;
- тёплая мультяшная кальянная-лаунж с диванами, столом и официантом;
- мемные интерактивные предметы с cooldown и полномочиями ведущего.

## Структура

- `src/` — Roblox-источник для Rojo;
- `catalog/` — локальный сервис каталога и импортёр `.siq`;
- `docs/` — спецификация и результаты исследования;
- `tasks/` — план и чеклист реализации.

## Локальный каталог паков и Steam Workshop

Нужен `uv` (он сам подтянет Python 3.11; отдельная установка Python не требуется).

```powershell
uv run --python 3.11 python -m catalog.catalog_service
```

Сервис запускается на `http://127.0.0.1:8787`, принимает `.siq` через `POST /packs/import`, а также даёт Roblox два маршрута:

- `GET /workshop/search?q=...&tag=...` — каталог с официальными метаданными Steam Workshop;
- `POST /workshop/install` с `{ "workshopId": "..." }` — скачивание пака через серверный SteamCMD-воркер, проверка `.siq` и импорт.

Для установки из Workshop backend автоматически использует `.tools/steamcmd/steamcmd.exe`, если он есть; иначе можно задать `STEAMCMD_PATH` и `STEAMCMD_WORKDIR`. `STEAM_WEB_API_KEY` необязателен: с ним поиск использует `IPublishedFileService`, без него включается публичный browse-fallback. Для паков, закрытых для anonymous download, задаются `STEAMCMD_USER` и `STEAMCMD_PASSWORD` только в окружении процесса — в репозиторий они не попадают. В опубликованной Roblox-игре `Config.CatalogUrl` должен указывать на доступный по HTTPS backend, а HTTP Requests должны быть включены в настройках опыта.

## Roblox-разработка

Для синхронизации исходников с Roblox Studio используется Rojo. Локальная сборка проверяется командой:

```powershell
.tools\rojo\rojo.exe build default.project.json -o .tools\SIGameLounge.rbxlx
```

Проверка импортёра и форматов SIQ:

```powershell
uv run --python 3.11 python -m unittest discover -s catalog/tests -v
```

Реальный multi-client playtest всё ещё нужно провести в Roblox Studio.

## Быстрый запуск сегодня вечером

1. Открой `.tools/SIGameLounge_Final.rbxl` в Roblox Studio.
2. Нажми Play: ведущий выбирает «Создать комнату», остальные — «Игрок». Код комнаты появится в шапке.
3. Открой «ПАКИ • КАТАЛОГ». Без backend сразу доступен встроенный demo-пак; ведущий может выбрать его или открыть голосование, а игроки — предложить и проголосовать.
4. Для реального Workshop-каталога в отдельном PowerShell окне выполни:

```powershell
uv run --python 3.11 python -m catalog.catalog_service
```

5. Включи `Allow HTTP requests` в Experience Settings Roblox Studio, если нужен внешний Workshop backend.

Текущая локальная сборка уже настроена на временный HTTPS quick tunnel для каталога. Для сегодняшнего теста оставь запущенными backend и `.tools/cloudflared.exe tunnel --url http://127.0.0.1:8787`; для постоянного релиза замени `Config.CatalogUrl` на свой стабильный HTTPS-домен.

## Визуальные референсы

- [Лаунж и рассадка ведущего](art/lounge-concept.png)
- [Макет внутриигрового каталога](art/catalog-mockup.png)
- [Финальный концепт lounge-сцены](art/sigame-lounge-render.png)

## Решение по внешним проектам

Мы используем идеи и совместимые открытые инструменты, но не копируем чужие проекты целиком:

- `Roblox/creator-docs` — справочник по официальным API;
- `rib3ye/RoInit` — ориентир для toolchain и CI;
- `Roblox/react-luau` — возможный источник идей для UI, но MVP остаётся на простом native Luau UI;
- `Roblox/testez` — ориентир для тестов Luau;
- `S4US/Roqer` — инструмент разработки/автоматизации Studio, не runtime-зависимость игры;
- `alpineQ/sigame`, `donebd/SIGame` и официальный `VladimirKhil/SI` — источники для понимания `.siq` и механики.

