# BussinessRunner

Нативное macOS-приложение (SwiftUI) — канва проджект-менеджера для docs-only разработки. Save пишет пакет `/.harness/` в целевой git-репозиторий.

## Как открыть

1. Ключ Cursor API лежит локально в `.env` (файл в `.gitignore`) и/или в Keychain (`service=BussinessRunner`). Скопируйте `.env.example` → `.env` и заполните `CURSOR_API_KEY`, если ключа ещё нет.
2. Сборка:
   - Xcode: `open BussinessRunner.xcodeproj`, схема **BussinessRunner**, Run.
   - Или: `make app` (компиляция через Swift/CLT в `dist/BussinessRunner.app`).
3. Запуск: `open dist/BussinessRunner.app` либо Run из Xcode.
4. Проверка harness без UI: `make selftest`.

Минимум macOS 26. Интерфейс русский, Liquid Glass / unified toolbar.

## Цикл v0

Проект → вкладки (Платформы / Сущности / Роли / Правила / Процессы / Тикеты) → редактор процесса → **Сохранить harness** в целевой репозиторий.
