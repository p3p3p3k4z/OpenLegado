// Implementacion propuesta
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http; // Para llamar a tu backend
import 'dart:convert';

class PaymentScreenStripe extends StatefulWidget {
  const PaymentScreenStripe({super.key});

  @override
  _PaymentScreenStripeState createState() => _PaymentScreenStripeState();
}

class _PaymentScreenStripeState extends State<PaymentScreenStripe> {
  CardFieldInputDetails? _cardDetails;
  bool _isPaying = false;

  // ESTA URL APUNTARÁ A TU BACKEND
  final String _backendUrl = 'https://tu-backend.com/create-payment-intent'; // ¡REEMPLAZA ESTO!

  Future<Map<String, dynamic>> _fetchPaymentIntentClientSecret() async {
    try {
      // Llama a tu backend para crear un PaymentIntent
      final response = await http.post(
        Uri.parse(_backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': 'cliente@example.com', // Envía datos relevantes
          'amount': 2000, // Ejemplo: 2000 centavos = $20.00 USD
          'currency': 'usd', // o la moneda que necesites
          // 'payment_method_types': ['card'], // Puedes especificarlo
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        // Manejar error de backend
        throw Exception('Failed to create PaymentIntent: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to connect to backend: $e');
    }
  }

  Future<void> _handlePayPress() async {
    if (_cardDetails == null || !_cardDetails!.complete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa los datos de la tarjeta.')),
      );
      return;
    }

    setState(() => _isPaying = true);

    try {
      // 1. Obtener el client_secret del PaymentIntent desde tu backend
      final Map<String, dynamic> intentData = await _fetchPaymentIntentClientSecret();
      final clientSecret = intentData['clientSecret'] as String?;
      // Podrías tener otros datos como el ID del intent si lo necesitas
      // final paymentIntentId = intentData['paymentIntentId'] as String?;


      if (clientSecret == null) {
        throw Exception('Client secret no recibido del backend.');
      }

      // 2. Confirmar el pago en el cliente
      final paymentIntentResult = await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: clientSecret,
        data: PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(
            billingDetails: BillingDetails(
              email: 'cliente@example.com', // Opcional pero recomendado
              // ... más detalles de facturación si los tienes
            ),
          ),
        ),
      );

      if (paymentIntentResult.status == PaymentIntentsStatus.Succeeded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Pago exitoso!')),
        );
        // Aquí navegas a una pantalla de éxito, actualizas el estado del pedido, etc.
      } else if (paymentIntentResult.status == PaymentIntentsStatus.RequiresAction) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Se requiere autenticación adicional.')),
        );
        // Stripe SDK usualmente maneja la redirección para 3D Secure
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pago fallido: ${paymentIntentResult.status}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isPaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pagar con Stripe')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CardField(
              onCardChanged: (details) {
                setState(() {
                  _cardDetails = details;
                });
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isPaying || (_cardDetails == null || !_cardDetails!.complete)
                  ? null
                  : _handlePayPress,
              child: _isPaying
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Pagar \$20.00'),
            ),
          ],
        ),
      ),
    );
  }
}
