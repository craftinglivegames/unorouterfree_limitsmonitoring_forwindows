# UnoRouter Free Monitor — мониторинг квоты UnoRouter в трее Windows

Трей-индикатор расхода квоты **[UnoRouter](https://unorouter.com)**. Показывает,
сколько потрачено сегодня и за месяц, и сколько осталось от лимита — в процентах
и в долларах.

## Что это и откуда данные

UnoRouter — это OpenAI-совместимый роутер (relay) к разным моделям, включая
бесплатные `:free`. Квота у него денежная: у ключа есть лимит (`hard_limit_usd`)
и накопленный расход (`total_usage`). Монитор читает это напрямую с API:

```
GET https://api.unorouter.com/v1/dashboard/billing/subscription
GET https://api.unorouter.com/v1/dashboard/billing/usage?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD
Authorization: Bearer sk-...
```

> Важно: ключ работает на `api.unorouter.com`. Хост `unorouter.ai/v1/...`
> отдаёт на тот же ключ `401 invalid_api_key` — это разные шлюзы.

## Что видно в трее

- Круглая иконка с процентом израсходованного лимита за месяц.
- Синий — всё в порядке, оранжевый — от 70%, красный — от 90%, `!` — 100%+.
- Буква `U` на иконке — лимит не задан (аккаунт без ограничения), процент не считается.
- Подсказка при наведении: `UnoRouter: сегодня 0,00$ · месяц 0,00$ · без лимита`.
- Правый клик — меню: «Обновить сейчас», «Открыть кабинет UnoRouter», «Выход».
- Уведомление при достижении 90% лимита.

## Установка

```powershell
git clone https://github.com/craftinglivegames/unorouterfree_limitsmonitoring_forwindows.git
cd unorouterfree_limitsmonitoring_forwindows

# 1. Создать свой конфиг из шаблона
Copy-Item config.example.json config.json

# 2. Открыть config.json и вставить свой ключ
notepad config.json

# 3. Запустить (без окна консоли)
.\UnoRouterUsage.vbs
```

Иконка появится в трее. Windows 11 может спрятать её в область переполнения —
нажмите `^` слева от часов и перетащите иконку на панель, если хотите держать
её на виду.

## Куда вводить ключ

Файл **`config.json`** в папке программы:

```json
{
  "api_key": "sk-ВАШ_КЛЮЧ",
  "update_interval": 300
}
```

Ключ создаётся в кабинете UnoRouter: <https://unorouter.com/en/token> → Create
token. Выглядит как `sk-...`.

| Параметр | По умолчанию | Описание |
| --- | --- | --- |
| `api_key` | — | Ваш ключ UnoRouter (обязательно) |
| `update_interval` | `300` | Период опроса, сек (60–3600) |

## Проверка без запуска трея

```powershell
powershell -ExecutionPolicy Bypass -File .\UnoRouterUsage.ps1 -Once
```

Пример вывода:

```
UnoRouter: сегодня 0,00 USD · месяц 0,00 USD · лимит без лимита · использовано 0%
```

## Автозапуск

Создайте ярлык на `UnoRouterUsage.vbs` в папке автозагрузки:

```
Win+R → shell:startup → положить туда ярлык на UnoRouterUsage.vbs
```

## Файлы

| Файл | Назначение |
| --- | --- |
| `UnoRouterUsage.ps1` | Вся логика: запросы к API, иконка, меню, уведомления |
| `config.example.json` | Шаблон конфига — скопировать в `config.json` |
| `UnoRouterUsage.vbs` | Тихий запуск без окна консоли |
| `icon.png` | Заготовка иконки (в трее рисуется динамическая) |
| `unorouter-usage.log` | Журнал запросов и ошибок |

## Безопасность

- `config.json` с ключом **исключён** из репозитория (`.gitignore`) — в git
  попадает только `config.example.json` с заглушкой.
- Ключ отправляется только на `api.unorouter.com` в заголовке
  `Authorization: Bearer`.
- Никакие данные никуда больше не передаются.
