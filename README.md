#UnoRouter Free Monitor — бесплатная квота UnoRouter в трее Windows

Индикатор дневной бесплатной квоты UnoRouter в системном трее.
Данные берутся с эндпоинта OpenRouter (`https://openrouter.ai/api/v1/key`),
так как UnoRouter использует тот же счётчик `free_model_daily_requests`.

Показывает: использовано / лимит / процент / осталося.
Цвет иконки: зелёный → оранжевый (70%+) → красный (90%+) → тёмно-красный «!» (100%).
Уведомления при 90%, 100%, сбросе квоты.

## Установка

```powershell
git clone https://github.com/craftinglivegames/unorouterfree_limitsmonitoring_forwindows-.git
cd unorouterfree_limitsmonitoring_forwindows-
Copy-Item config.example.json config.json
# вставьте свой ключ UnoRouter в config.json
.\UnoRouterUsage.vbs
```

Иконка появится в скрытой области трея (`^`). Перетащите на панель для постоянного видения.

## Настройка

Копируйте `config.example.json` в `config.json` (не коммитьте реальный ключ):

```json
{
  "api_key": "sk-Ko3r4lHOLCwH2a8...ВАШ_КЛЮЧ_СЮДА",
  "update_interval": 300
}
```

Где взять ключ: UnoRouter → Settings / API Keys → Create Key (или используйте тот же ключ OpenRouter, если он работает и для UnoRouter).

## Проверка

```powershell
powershell -ExecutionPolicy Bypass -File .\UnoRouterUsage.ps1 -Once
```

## Безопасность

Ваш `api_key` хранится только в локальном `config.json`. Репозиторий содержит только шаблон `config.example.json`. Не публикуйте реальный ключ.
