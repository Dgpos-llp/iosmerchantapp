class OnlineOrderReport {
  final String paymentMode;
  final DateTime orderDateTime;
  final int restaurantId;
  final double grossAmount;
  final String restaurantName;
  final String onlineOrderId;
  final String orderFrom;
  final String externalOrderId;
  final String phoneNumber;
  final double netAmount;
  final String customerName;
  final String orderType;
  final String status;

  OnlineOrderReport({
    required this.paymentMode,
    required this.orderDateTime,
    required this.restaurantId,
    required this.grossAmount,
    required this.restaurantName,
    required this.onlineOrderId,
    required this.orderFrom,
    required this.externalOrderId,
    required this.phoneNumber,
    required this.netAmount,
    required this.customerName,
    required this.orderType,
    required this.status,
  });

  factory OnlineOrderReport.fromJson(Map<String, dynamic> json) {
    return OnlineOrderReport(
      paymentMode: json['payment_mode'] ?? "",
      orderDateTime: json['order_date_time'] != null
          ? DateTime.parse(json['order_date_time'])
          : DateTime.now(),
      restaurantId: json['restaurant_id'] ?? 0,
      grossAmount: (json['gross_amount'] as num?)?.toDouble() ?? 0.0,
      restaurantName: json['restaurant_name'] ?? "",
      onlineOrderId: json['online_order_id'] ?? "",
      orderFrom: json['order_from'] ?? "",
      externalOrderId: json['external_order_id'] ?? "",
      phoneNumber: json['phone_number'] ?? "",
      netAmount: (json['net_amount'] as num?)?.toDouble() ?? 0.0,
      customerName: json['customer_name'] ?? "",
      orderType: json['order_type'] ?? "",
      status: json['status'] ?? "",
    );
  }

  // Helper method to get Gross Amount formatted to 3 decimal places
  String get formattedGrossAmount => grossAmount.toStringAsFixed(3);

  // Helper method to get Net Amount formatted to 3 decimal places
  String get formattedNetAmount => netAmount.toStringAsFixed(3);
}