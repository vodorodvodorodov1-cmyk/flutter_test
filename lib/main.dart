import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────
// 1. МОДЕЛЬ
// ─────────────────────────────────────────────

class Order {
  final int orderId;
  final String status;
  final String? paymentUrl;

  const Order({
    required this.orderId,
    required this.status,
    this.paymentUrl,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      orderId: json['order_id'] as int,
      status: json['status'] as String,
      paymentUrl: json['payment_url'] as String?,
    );
  }

  @override
  String toString() =>
      'Order(orderId: $orderId, status: $status, paymentUrl: $paymentUrl)';
}

// ─────────────────────────────────────────────
// 2. КАСТОМНОЕ ИСКЛЮЧЕНИЕ
// ─────────────────────────────────────────────

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => statusCode != null
      ? 'ApiException [$statusCode]: $message'
      : 'ApiException: $message';
}

// ─────────────────────────────────────────────
// 3. СЕРВИС — createOrder
// ─────────────────────────────────────────────

class OrderService {
  final String baseUrl;
  final http.Client _client;

  OrderService({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<Order> createOrder({
    required int userId,
    required int serviceId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/orders');
    final body = jsonEncode({'userId': userId, 'serviceId': serviceId});

    late http.Response response;

    try {
      response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));
    } on SocketException {
      throw const ApiException('Нет подключения к интернету');
    } on TimeoutException {
      throw const ApiException('Превышено время ожидания (10 с)');
    } catch (e) {
      throw ApiException('Неизвестная ошибка: $e');
    }

    if (response.statusCode == 200) {
      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return Order.fromJson(json);
      } catch (_) {
        throw const ApiException('Ошибка разбора ответа сервера');
      }
    } else {
      String errorMessage;
      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        errorMessage =
            json['message'] as String? ?? json['error'] as String? ?? 'Ошибка сервера';
      } catch (_) {
        errorMessage = 'Ошибка сервера (код ${response.statusCode})';
      }
      throw ApiException(errorMessage, statusCode: response.statusCode);
    }
  }
}

// ─────────────────────────────────────────────
// 4. КОНТРОЛЛЕР
// ─────────────────────────────────────────────

enum OrderState { initial, loading, success, error }

class OrderController extends ChangeNotifier {
  final OrderService _service;

  OrderController(this._service);

  OrderState _state = OrderState.initial;
  OrderState get state => _state;

  Order? _order;
  Order? get order => _order;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool get isLoading => _state == OrderState.loading;

  Future<void> submitOrder({
    required int userId,
    required int serviceId,
  }) async {
    _state = OrderState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _order = await _service.createOrder(
        userId: userId,
        serviceId: serviceId,
      );
      _state = OrderState.success;
    } on ApiException catch (e) {
      _state = OrderState.error;
      _errorMessage = e.message;
    } catch (e) {
      _state = OrderState.error;
      _errorMessage = 'Непредвиденная ошибка: $e';
    }

    notifyListeners();
  }

  void reset() {
    _state = OrderState.initial;
    _order = null;
    _errorMessage = null;
    notifyListeners();
  }
}

// ─────────────────────────────────────────────
// 5. ВИДЖЕТ
// ─────────────────────────────────────────────

class CreateOrderScreen extends StatefulWidget {
  final OrderController controller;

  const CreateOrderScreen({super.key, required this.controller});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  static const _userId = 42;
  static const _serviceId = 7;

  OrderController get _ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() => setState(() {});

  void _submit() {
    _ctrl.submitOrder(userId: _userId, serviceId: _serviceId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Новый заказ',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildOrderCard(),
              const SizedBox(height: 24),
              _buildStatusArea(),
              const Spacer(),
              _buildActionButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(Icons.person_outline, 'Пользователь', '#$_userId'),
          const SizedBox(height: 12),
          _infoRow(Icons.build_outlined, 'Услуга', '#$_serviceId'),
          if (_ctrl.state == OrderState.success && _ctrl.order != null) ...[
            const Divider(height: 24),
            _infoRow(
              Icons.receipt_long_outlined,
              'Номер заказа',
              '#${_ctrl.order!.orderId}',
            ),
            const SizedBox(height: 12),
            _infoRow(
              Icons.check_circle_outline,
              'Статус',
              _ctrl.order!.status,
              valueColor: Colors.green,
            ),
            if (_ctrl.order!.paymentUrl != null) ...[
              const SizedBox(height: 12),
              _infoRow(
                Icons.link,
                'Ссылка на оплату',
                _ctrl.order!.paymentUrl!,
                valueColor: Colors.blue,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade500),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusArea() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: switch (_ctrl.state) {
        OrderState.loading => const _LoadingBanner(),
        OrderState.error => _ErrorBanner(message: _ctrl.errorMessage ?? 'Ошибка'),
        OrderState.success => const _SuccessBanner(),
        OrderState.initial => const SizedBox.shrink(),
      },
    );
  }

  Widget _buildActionButton() {
    final isLoading = _ctrl.isLoading;
    final isError = _ctrl.state == OrderState.error;
    final isSuccess = _ctrl.state == OrderState.success;

    if (isSuccess) {
      return OutlinedButton.icon(
        onPressed: _ctrl.reset,
        icon: const Icon(Icons.refresh),
        label: const Text('Создать ещё один'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }

    return FilledButton(
      onPressed: isLoading ? null : _submit,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isError ? Colors.orange : Colors.deepPurple,
        disabledBackgroundColor: Colors.deepPurple.shade100,
      ),
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
            )
          : Text(
              isError ? 'Повторить попытку' : 'Создать заказ',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
    );
  }
}

// ── Вспомогательные баннеры ───────────────────

class _LoadingBanner extends StatelessWidget {
  const _LoadingBanner();
  @override
  Widget build(BuildContext context) => _Banner(
        color: Colors.deepPurple.shade50,
        icon: Icons.hourglass_top_rounded,
        iconColor: Colors.deepPurple,
        text: 'Отправляем заказ…',
      );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) => _Banner(
        color: Colors.red.shade50,
        icon: Icons.error_outline,
        iconColor: Colors.red,
        text: message,
      );
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner();
  @override
  Widget build(BuildContext context) => _Banner(
        color: Colors.green.shade50,
        icon: Icons.check_circle_outline,
        iconColor: Colors.green,
        text: 'Заказ успешно создан!',
      );
}

class _Banner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final Color iconColor;
  final String text;

  const _Banner({
    required this.color,
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: iconColor,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ТОЧКА ВХОДА
// ─────────────────────────────────────────────

void main() {
  final service = OrderService(baseUrl: 'https://api.example.com');
  final controller = OrderController(service);

  runApp(
    MaterialApp(
      title: 'Create Order Demo',
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: CreateOrderScreen(controller: controller),
    ),
  );
}
