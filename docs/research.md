# Исследование инструментов и аналогов

## Что взять для разработки

| Проект | Решение | Почему |
|---|---|---|
| [RoInit](https://github.com/rib3ye/RoInit) | Взять идеи toolchain | Rojo, Wally, Selene, StyLua, Lune и CI уже собраны в понятный стартовый контур; лицензия MIT. |
| [react-luau](https://github.com/Roblox/react-luau) | Не включать в MVP | Это read-only mirror React 17 для Luau; для первой версии native UI проще и надёжнее. |
| [roact](https://github.com/Roblox/roact) | Не включать | Репозиторий архивирован; не добавляем устаревшую UI-зависимость без необходимости. |
| [testez](https://github.com/Roblox/testez) | Рассмотреть на фазе тестов | Подходит для BDD-тестов Luau, но сначала проверяем игровые правила простыми тестами. |
| [roblox-blender-plugin](https://github.com/Roblox/roblox-blender-plugin) | Взять позже для lounge-моделей | Нужен для controlled upload ассетов из Blender через Roblox Open Cloud, не для runtime. |
| [tarmac](https://github.com/Roblox/tarmac) | Рассмотреть для asset pipeline | Может помочь управлять Roblox-ассетами, но не нужен для первого игрового среза. |
| [Roqer](https://github.com/S4US/Roqer) | Использовать как dev-инструмент | Может читать/править Studio, запускать multi-client playtest и работать с Blender; AGPL-3.0, поэтому код игры от него не копируем и runtime-зависимость не добавляем. |

## Что использовать как reference для SIGame

- [VladimirKhil/SI](https://github.com/VladimirKhil/SI) — официальный открытый исходный код SIGame, модель паков и игровая архитектура.
- [SIQ file format v5](https://github.com/VladimirKhil/SI/wiki/SIQ-file-format-version-5) — `.siq` является ZIP-архивом с `content.xml` и каталогами медиа.
- [alpineQ/sigame](https://github.com/alpineQ/sigame) — практический пример чтения `.siq` v4/v5 прямо при запуске; используем как reference, но не копируем код без явной лицензии.
- [donebd/SIGame](https://github.com/donebd/SIGame) — MIT-проект с импортом `.siq`, полезен для тестовых сценариев и UX ведущего.

## Идеи из актуальных party-game форматов

- [Jackbox player limits](https://support.jackboxgames.com/hc/en-us/articles/15794756085015-How-many-players-can-join-each-game) — пульт игрока с отдельного устройства и роль ведущего.
- [Grouparty](https://grouparty.com/about) — общий экран плюс телефон каждого игрока; это подтверждает выбранный для нас формат.
- [Jackbox Party Essentials](https://media.netflix.com/en/only-on-netflix/82089527) — короткие смешные режимы и быстрый вход в компанию; такие идеи пойдут в будущие дополнительные режимы, не в основной классический SIGame.

## Roblox-ограничения, влияющие на архитектуру

- [HttpService](https://create.roblox.com/docs/reference/engine/classes/HttpService) позволяет обращаться к внешнему API, но запросы должны идти к доверенному сервису; лимит внешних HTTP-запросов — 500 в минуту на сервер игры.
- [ImageLabel](https://create.roblox.com/docs/reference/engine/classes/ImageLabel) ожидает Roblox image/decal asset, поэтому внешняя картинка из `.siq` не может просто стать `ImageLabel.Image` по URL.
- [TextService](https://create.roblox.com/docs/reference/engine/classes/TextService) и [chat guidelines](https://create.roblox.com/docs/chat/guidelines) требуют фильтровать пользовательский текст и не использовать самодельный чат вместо `TextChatService`.

## Решение

Для MVP выбран простой вертикальный срез: native Luau UI + сервер-авторитетная игровая логика + отдельный dependency-free сервис импорта `.siq`. Тяжёлые фреймворки и AI-инструменты остаются опциональными инструментами разработки.

