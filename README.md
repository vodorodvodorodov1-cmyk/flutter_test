# Flutter Order Demo

Flutter-приложение, демонстрирующее создание заказов через REST API с чистой MVC-архитектурой, обработкой ошибок и анимированным UI на Material 3.

## Структура проекта

```
flutter_order_demo/
├── lib/
│   └── main.dart          # Весь код приложения (модель, сервис, контроллер, UI)
├── test/
│   └── (unit-тесты)       # Место для тестов OrderService и OrderController
├── pubspec.yaml           # Зависимости и метаданные проекта
├── .gitignore
└── README.md
```

---

## Что внутри

| Слой | Класс | Описание |
|---|---|---|
| **Модель** | `Order` | Данные заказа: `orderId`, `status`, `paymentUrl` |
| **Исключение** | `ApiException` | Типизированная ошибка с кодом HTTP |
| **Сервис** | `OrderService` | HTTP-клиент, `POST /api/orders`, таймаут 10 с |
| **Контроллер** | `OrderController` | `ChangeNotifier`, состояния: `initial → loading → success/error` |
| **UI** | `CreateOrderScreen` | Material 3, `AnimatedSwitcher`, баннеры состояний |

---

## 🚀 Быстрый старт

### Требования

- Flutter SDK `>=3.0.0`
- Dart SDK `>=3.0.0`

### Установка и запуск

```bash
# 1. Клонировать репозиторий
git clone https://github.com/YOUR_USERNAME/flutter_order_demo.git
cd flutter_order_demo

# 2. Установить зависимости
flutter pub get

# 3. Запустить приложение
flutter run
```

> **Важно:** В `main.dart` прописан `baseUrl: 'https://api.example.com'` — замените на URL вашего реального API перед запуском.

---

## Конфигурация API

Откройте `lib/main.dart` и найдите точку входа в самом низу файла:

```dart
void main() {
  final service = OrderService(baseUrl: 'https://api.example.com'); // ← сюда ваш URL
  ...
}
```

Приложение отправляет `POST /api/orders` с телом:

```json
{
  "userId": 42,
  "serviceId": 7
}
```

Ожидаемый ответ сервера (`200 OK`):

```json
{
  "order_id": 123,
  "status": "pending",
  "payment_url": "https://pay.example.com/123"  // опционально
}
```

---

## Скриншоты состояний

| Initial | Loading | Success | Error |
|---|---|---|---|
| Кнопка «Создать заказ» | Индикатор + баннер | Данные заказа + зелёный баннер | Оранжевая кнопка «Повторить» |

---

## 🧪 Тестирование

```bash
flutter test
```

`OrderService` принимает кастомный `http.Client` — это позволяет легко подменить его моком в тестах через `mockito`.

---