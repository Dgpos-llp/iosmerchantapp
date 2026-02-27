//no change
class TotalSalesReport {
  final String occupiedTables;
  final String onlineSales;
  final String billDiscount;
  final String endDate;
  final String counterTotal;
  final String netSales;
  final String totalSales;
  final String roundOffTotal;
  final String onlineOrders;
  final String homeDeliveryChargeTotal;
  final String totalKotEntries;
  final String homeDeliveryTotal;
  final String billTimes;
  final String billTax;
  final String dineTotal;
  final String takeAwayTotal;
  final String onlineTotal;
  final String homeDeliverySales;
  final String counterSales;
  final String occupiedTableCount;
  final String startDate;
  final String dineInSales;
  final String takeAwaySales;
  final String dineInOrders;
  final String takeAwayOrders;
  final String homeDeliveryOrders;
  final String totalOrders;
  final Map<String, dynamic> settlementAmounts;

  TotalSalesReport({
    required this.occupiedTables,
    required this.onlineSales,
    required this.billDiscount,
    required this.endDate,
    required this.counterTotal,
    required this.netSales,
    required this.totalSales,
    required this.roundOffTotal,
    required this.onlineOrders,
    required this.homeDeliveryChargeTotal,
    required this.totalKotEntries,
    required this.homeDeliveryTotal,
    required this.billTimes,
    required this.billTax,
    required this.dineTotal,
    required this.takeAwayTotal,
    required this.onlineTotal,
    required this.homeDeliverySales,
    required this.counterSales,
    required this.occupiedTableCount,
    required this.startDate,
    required this.dineInSales,
    required this.takeAwaySales,
    required this.dineInOrders,
    required this.takeAwayOrders,
    required this.homeDeliveryOrders,
    required this.totalOrders,
    required this.settlementAmounts,
  });

  factory TotalSalesReport.fromJson(Map<String, dynamic> json) {
    return TotalSalesReport(
      occupiedTables: json['occupiedTables']?.toString() ?? "",
      onlineSales: json['onlineSales']?.toString() ?? "",
      billDiscount: json['billDiscount']?.toString() ?? "",
      endDate: json['endDate']?.toString() ?? "",
      counterTotal: json['counterTotal']?.toString() ?? "",
      netSales: json['netTotal']?.toString() ?? json['netSales']?.toString() ?? "",
      totalSales: json['grandTotal']?.toString() ?? json['totalSales']?.toString() ?? "",
      roundOffTotal: json['roundOffTotal']?.toString() ?? "",
      onlineOrders: json['onlineOrders']?.toString() ?? "",
      homeDeliveryChargeTotal: json['homeDeliveryChargeTotal']?.toString() ?? "",
      totalKotEntries: json['totalKotEntries']?.toString() ?? "",
      homeDeliveryTotal: json['homeDeliveryTotal']?.toString() ?? "",
      billTimes: json['billTimes']?.toString() ?? "",
      billTax: json['billTax']?.toString() ?? "",
      dineTotal: json['dineInSales']?.toString() ?? json['dineTotal']?.toString() ?? "",
      takeAwayTotal: json['takeAwaySales']?.toString() ?? json['takeAwayTotal']?.toString() ?? "",
      onlineTotal: json['onlineSales']?.toString() ?? "",
      homeDeliverySales: json['homeDeliverySales']?.toString() ?? "",
      counterSales: json['counterSales']?.toString() ?? "",
      occupiedTableCount: json['occupiedTableCount']?.toString() ?? "",
      startDate: json['startDate']?.toString() ?? "",
      dineInSales: json['dineInSales']?.toString() ?? "",
      takeAwaySales: json['takeAwaySales']?.toString() ?? "",
      dineInOrders: json['dineInOrders']?.toString() ?? "0",
      takeAwayOrders: json['takeAwayOrders']?.toString() ?? "0",
      homeDeliveryOrders: json['homeDeliveryOrders']?.toString() ?? "0",
      totalOrders: json['totalOrders']?.toString() ?? "0",
      settlementAmounts: json['settlementAmounts'] ?? {},
    );
  }

  String getField(String key, {String fallback = "0.000"}) {
    String value = "";
    switch (key) {
      case "occupiedTables": value = occupiedTables.isNotEmpty ? occupiedTables : fallback; break;
      case "occupiedTableCount": value = occupiedTableCount.isNotEmpty ? occupiedTableCount : (occupiedTables.isNotEmpty ? occupiedTables : fallback); break;
      case "onlineSales": value = onlineSales.isNotEmpty ? onlineSales : fallback; break;
      case "billDiscount": value = billDiscount.isNotEmpty ? billDiscount : fallback; break;
      case "endDate": return endDate.isNotEmpty ? endDate : fallback;
      case "counterTotal":
      case "counterSales": value = counterTotal.isNotEmpty ? counterTotal : (counterSales.isNotEmpty ? counterSales : fallback); break;
      case "netSales":
      case "netTotal": value = netSales.isNotEmpty ? netSales : fallback; break;
      case "totalSales":
      case "grandTotal": value = totalSales.isNotEmpty ? totalSales : fallback; break;
      case "roundOffTotal": value = roundOffTotal.isNotEmpty ? roundOffTotal : fallback; break;
      case "onlineOrders": value = onlineOrders.isNotEmpty ? onlineOrders : fallback; break;
      case "homeDeliveryChargeTotal": value = homeDeliveryChargeTotal.isNotEmpty ? homeDeliveryChargeTotal : fallback; break;
      case "totalKotEntries": value = totalKotEntries.isNotEmpty ? totalKotEntries : fallback; break;
      case "homeDeliveryTotal": value = homeDeliveryTotal.isNotEmpty ? homeDeliveryTotal : fallback; break;
      case "homeDeliverySales": value = homeDeliverySales.isNotEmpty ? homeDeliverySales : fallback; break;
      case "billTimes": return billTimes.isNotEmpty ? billTimes : fallback;
      case "billTax": value = billTax.isNotEmpty ? billTax : fallback; break;
      case "dineTotal":
      case "dineInSales": value = dineTotal.isNotEmpty ? dineTotal : (dineInSales.isNotEmpty ? dineInSales : fallback); break;
      case "takeAwayTotal":
      case "takeAwaySales": value = takeAwayTotal.isNotEmpty ? takeAwayTotal : (takeAwaySales.isNotEmpty ? takeAwaySales : fallback); break;
      case "startDate": return startDate.isNotEmpty ? startDate : fallback;
      case "dineInOrders": return dineInOrders.isNotEmpty ? dineInOrders : fallback;
      case "takeAwayOrders": return takeAwayOrders.isNotEmpty ? takeAwayOrders : fallback;
      case "homeDeliveryOrders": return homeDeliveryOrders.isNotEmpty ? homeDeliveryOrders : fallback;
      case "totalOrders": return totalOrders.isNotEmpty ? totalOrders : fallback;
      default: value = fallback;
    }

    // Attempt to format numeric strings to 3 decimals
    double? parsed = double.tryParse(value);
    return parsed != null ? parsed.toStringAsFixed(3) : value;
  }
}

class TimeslotSales {
  final String timeslot;
  final double dineInSales;
  final double takeAwaySales;
  final double deliverySales;
  final double onlineSales;
  final double counterSales;

  TimeslotSales({
    required this.timeslot,
    required this.dineInSales,
    required this.takeAwaySales,
    required this.deliverySales,
    required this.onlineSales,
    required this.counterSales,
  });

  factory TimeslotSales.fromJson(Map<String, dynamic> json) {
    double parse(dynamic value) => (value is num) ? value.toDouble() : double.tryParse(value?.toString() ?? "0.000") ?? 0.0;
    return TimeslotSales(
      timeslot: json['timeslot']?.toString() ?? "",
      dineInSales: parse(json['dineInSales']),
      takeAwaySales: parse(json['takeAwaySales']),
      deliverySales: parse(json['deliverySales']),
      onlineSales: parse(json['onlineSales']),
      counterSales: parse(json['counterSales'] ?? json['counter']),
    );
  }
}

class ItemwiseReport {
  final String productCode;
  final String productName;
  final double totalQntSold;
  final String totalSaleAmount;

  ItemwiseReport({
    required this.productCode,
    required this.productName,
    required this.totalQntSold,
    required this.totalSaleAmount,
  });

  factory ItemwiseReport.fromJson(Map<String, dynamic> json) {
    String amount = json['totalSaleAmount']?.toString() ?? '0.000';
    double? parsedAmount = double.tryParse(amount);
    return ItemwiseReport(
      productCode: json['productCode']?.toString() ?? '',
      productName: json['productName']?.toString() ?? '',
      totalQntSold: double.tryParse(json['totalQntSold']?.toString() ?? '0') ?? 0.0,
      totalSaleAmount: parsedAmount != null ? parsedAmount.toStringAsFixed(3) : amount,
    );
  }
}

class TaxwiseReport {
  final String billNo;
  final String billDate;
  final String taxableAmount;
  final Map<String, dynamic> taxAmounts;

  TaxwiseReport({
    required this.billNo,
    required this.billDate,
    required this.taxableAmount,
    required this.taxAmounts,
  });

  Map<String, dynamic> getTaxData() {
    return taxAmounts;
  }

  factory TaxwiseReport.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> taxes = {};
    String billNo = json['billNo']?.toString() ?? json['bill_No']?.toString() ?? '';
    String billDate = json['billDate']?.toString() ?? '';
    String taxableAmountRaw = json['taxableAmount']?.toString() ?? '0.000';
    double? parsedTaxable = double.tryParse(taxableAmountRaw);
    String taxableAmount = parsedTaxable != null ? parsedTaxable.toStringAsFixed(3) : taxableAmountRaw;

    json.forEach((key, value) {
      if (key != 'billNo' && key != 'bill_No' && key != 'billDate' && key != 'taxableAmount') {
        double? val = double.tryParse(value?.toString() ?? '');
        taxes[key] = val != null ? val.toStringAsFixed(3) : value;
      }
    });

    return TaxwiseReport(
      billNo: billNo,
      billDate: billDate,
      taxableAmount: taxableAmount,
      taxAmounts: taxes,
    );
  }
}

class SettlementwiseReport {
  final String billDate;
  final String settlementModeName;
  final String grossAmount;
  final double numberOfBills;
  final String percentToGross;

  SettlementwiseReport({
    required this.billDate,
    required this.settlementModeName,
    required this.grossAmount,
    required this.numberOfBills,
    required this.percentToGross,
  });

  factory SettlementwiseReport.fromJson(Map<String, dynamic> json) {
    String grossRaw = json['grossAmount']?.toString() ?? '0.000';
    double? parsedGross = double.tryParse(grossRaw);
    String percentRaw = json['percentToGross']?.toString() ?? '0.000';
    double? parsedPercent = double.tryParse(percentRaw);

    return SettlementwiseReport(
      billDate: json['billDate']?.toString() ?? '',
      settlementModeName: json['settlementModeName']?.toString() ?? '',
      grossAmount: parsedGross != null ? parsedGross.toStringAsFixed(3) : grossRaw,
      numberOfBills: double.tryParse(json['numberOfBills']?.toString() ?? '0') ?? 0.0,
      percentToGross: parsedPercent != null ? parsedPercent.toStringAsFixed(3) : percentRaw,
    );
  }
}

class DiscountwiseReport {
  final String billNo;
  final String billDate;
  final String amount;
  final String discount;
  final String netAmount;
  final String discountOnAmt;
  final String discountPercent;
  final String? remark;

  DiscountwiseReport({
    required this.billNo,
    required this.billDate,
    required this.amount,
    required this.discount,
    required this.netAmount,
    required this.discountOnAmt,
    required this.discountPercent,
    required this.remark,
  });

  factory DiscountwiseReport.fromJson(Map<String, dynamic> json) {
    String fmt(dynamic v) {
      double? d = double.tryParse(v?.toString() ?? '');
      return d != null ? d.toStringAsFixed(3) : (v?.toString() ?? '0.000');
    }

    return DiscountwiseReport(
      billNo: json['billNo']?.toString() ?? '',
      billDate: json['billDate']?.toString() ?? '',
      amount: fmt(json['amount']),
      discount: fmt(json['discount']),
      netAmount: fmt(json['netAmount']),
      discountOnAmt: fmt(json['discountOnAmt']),
      discountPercent: fmt(json['discountPercent']),
      remark: json['remark']?.toString(),
    );
  }
}

class OnlineCancelOrderReport {
  final String restaurantName;
  final String orderFrom;
  final String onlineOrderId;
  final String itemName;
  final double quantity;
  final double totalAmount;
  final double itemGrossTotal;
  final double unitPrice;
  final double orderGrossTotal;

  OnlineCancelOrderReport({
    required this.restaurantName,
    required this.orderFrom,
    required this.onlineOrderId,
    required this.itemName,
    required this.quantity,
    required this.totalAmount,
    required this.itemGrossTotal,
    required this.unitPrice,
    required this.orderGrossTotal,
  });

  factory OnlineCancelOrderReport.fromJson(Map<String, dynamic> json) {
    double parse(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0.0;
    return OnlineCancelOrderReport(
      restaurantName: json['restaurantName']?.toString() ?? '',
      orderFrom: json['orderFrom']?.toString() ?? '',
      onlineOrderId: json['onlineOrderId']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      quantity: parse(json['quantity']),
      totalAmount: parse(json['totalAmount']),
      itemGrossTotal: parse(json['itemGrossTotal']),
      unitPrice: parse(json['unitPrice']),
      orderGrossTotal: parse(json['orderGrossTotal']),
    );
  }
}

class KOTAnalysisReport {
  final String kotId;
  final String operation;
  final String date;
  final String time;
  final String billNo;
  final double qty;
  final String tableNumber;
  final String waiter;
  final String? reason;
  final String product;

  KOTAnalysisReport({
    required this.kotId,
    required this.operation,
    required this.date,
    required this.time,
    required this.billNo,
    required this.qty,
    required this.tableNumber,
    required this.waiter,
    required this.reason,
    required this.product,
  });

  factory KOTAnalysisReport.fromJson(Map<String, dynamic> json) {
    return KOTAnalysisReport(
      kotId: json['kotId']?.toString() ?? '',
      operation: json['operation']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      billNo: json['billNo']?.toString() ?? '',
      qty: double.tryParse(json['qty']?.toString() ?? '0') ?? 0.0,
      tableNumber: json['tableNumber']?.toString() ?? '',
      waiter: json['waiter']?.toString() ?? '',
      reason: json['reason']?.toString(),
      product: json['product']?.toString() ?? '',
    );
  }
}

class TimeAuditReport {
  final String billNo;
  final String tableNo;
  final String kotTime;
  final String billDate;
  final String billTime;
  final String settleDate;
  final String settleTime;
  final String userCreated;
  final String userEdited;
  final String? remarks;
  final String timeDifference;
  final String billAmount;
  final String settlementMode;

  TimeAuditReport({
    required this.billNo,
    required this.tableNo,
    required this.kotTime,
    required this.billDate,
    required this.billTime,
    required this.settleDate,
    required this.settleTime,
    required this.userCreated,
    required this.userEdited,
    required this.remarks,
    required this.timeDifference,
    required this.billAmount,
    required this.settlementMode,
  });

  factory TimeAuditReport.fromJson(Map<String, dynamic> json) {
    String amtRaw = json['billAmount']?.toString() ?? "0.000";
    double? parsedAmt = double.tryParse(amtRaw);
    return TimeAuditReport(
      billNo: json['billNo']?.toString() ?? "",
      tableNo: json['tableNo']?.toString() ?? "",
      kotTime: json['kotTime']?.toString() ?? "",
      billDate: json['billDate']?.toString() ?? "",
      billTime: json['billTime']?.toString() ?? "",
      settleDate: json['settleDate']?.toString() ?? "",
      settleTime: json['settleTime']?.toString() ?? "",
      userCreated: json['userCreated']?.toString() ?? "",
      userEdited: json['userEdited']?.toString() ?? "",
      remarks: json['remarks']?.toString(),
      timeDifference: json['timeDifference']?.toString() ?? "",
      billAmount: parsedAmt != null ? parsedAmt.toStringAsFixed(3) : amtRaw,
      settlementMode: json['settlementMode']?.toString() ?? "",
    );
  }
}

class CancelBillReport {
  final String kotId;
  final String billNo;
  final String billDate;
  final String cancelDate;
  final String createdTime;
  final String cancelTime;
  final String createdUser;
  final String cancelUser;
  final String? notes;
  final String billType;
  final String items;
  final String taxes;
  final String grandTotal;
  final String netTotal;

  CancelBillReport({
    required this.kotId,
    required this.billNo,
    required this.billDate,
    required this.cancelDate,
    required this.createdTime,
    required this.cancelTime,
    required this.createdUser,
    required this.cancelUser,
    required this.notes,
    required this.billType,
    required this.items,
    required this.taxes,
    required this.grandTotal,
    required this.netTotal,
  });

  factory CancelBillReport.fromJson(Map<String, dynamic> json) {
    String fmt(dynamic v) {
      double? d = double.tryParse(v?.toString() ?? '');
      return d != null ? d.toStringAsFixed(3) : (v?.toString() ?? '0.000');
    }
    return CancelBillReport(
      kotId: json['kot_ID']?.toString() ?? '',
      billNo: json['bill_No']?.toString() ?? '',
      billDate: json['billDate']?.toString() ?? '',
      cancelDate: json['cancelDate']?.toString() ?? '',
      createdTime: json['createdTime']?.toString() ?? '',
      cancelTime: json['cancelTime']?.toString() ?? '',
      createdUser: json['createdUser']?.toString() ?? '',
      cancelUser: json['cancelUser']?.toString() ?? '',
      notes: json['notes']?.toString(),
      billType: json['billType']?.toString() ?? '',
      items: json['items']?.toString() ?? '',
      taxes: fmt(json['taxes']),
      grandTotal: fmt(json['grandTotal']),
      netTotal: fmt(json['netTotal']),
    );
  }
}

class PaxWiseReport {
  final String billDate;
  final double totalPax;
  final String totalAmount;

  PaxWiseReport({
    required this.billDate,
    required this.totalPax,
    required this.totalAmount,
  });

  factory PaxWiseReport.fromJson(Map<String, dynamic> json) {
    String amtRaw = json['totalAmount']?.toString() ?? "0.000";
    double? parsedAmt = double.tryParse(amtRaw);
    return PaxWiseReport(
      billDate: json['billDate']?.toString() ?? "",
      totalPax: double.tryParse(json['totalPax']?.toString() ?? "0") ?? 0.0,
      totalAmount: parsedAmt != null ? parsedAmt.toStringAsFixed(3) : amtRaw,
    );
  }
}

class OnlineDaywiseReport {
  final String source;
  final String merchantId;
  final String orderId;
  final String orderDate;
  final String orderType;
  final String paymentMode;
  final String subtotal;
  final String discount;
  final String packagingCharge;
  final String deliveryCharge;
  final String tax;
  final String total;
  final String status;
  final String billNo;

  OnlineDaywiseReport({
    required this.source,
    required this.merchantId,
    required this.orderId,
    required this.orderDate,
    required this.orderType,
    required this.paymentMode,
    required this.subtotal,
    required this.discount,
    required this.packagingCharge,
    required this.deliveryCharge,
    required this.tax,
    required this.total,
    required this.status,
    required this.billNo,
  });

  factory OnlineDaywiseReport.fromJson(Map<String, dynamic> json) {
    String fmt(dynamic v) {
      double? d = double.tryParse(v?.toString() ?? '');
      return d != null ? d.toStringAsFixed(3) : (v?.toString() ?? '0.000');
    }
    return OnlineDaywiseReport(
      source: json['source']?.toString() ?? '',
      merchantId: json['merchantId']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      orderDate: json['orderDate']?.toString() ?? '',
      orderType: json['orderType']?.toString() ?? '',
      paymentMode: json['paymentMode']?.toString() ?? '',
      subtotal: fmt(json['subtotal']),
      discount: fmt(json['discount']),
      packagingCharge: fmt(json['packagingCharge']),
      deliveryCharge: fmt(json['deliveryCharge']),
      tax: fmt(json['tax']),
      total: fmt(json['total']),
      status: json['status']?.toString() ?? '',
      billNo: json['billNo']?.toString() ?? '',
    );
  }
}

class OrderSummaryReport {
  final String orderType;
  final double totalCount;
  final double totalAmount;

  OrderSummaryReport({
    required this.orderType,
    required this.totalCount,
    required this.totalAmount,
  });

  factory OrderSummaryReport.fromJson(Map<String, dynamic> json) {
    return OrderSummaryReport(
      orderType: json['orderType'] ?? '',
      totalCount: double.tryParse(json['totalCount']?.toString() ?? '0') ?? 0.0,
      totalAmount: double.tryParse(json['totalAmount']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class CancelKotReport {
  final String kotId;
  final double? quantity;
  final String? amount;
  final String status;
  final String? notes;
  final String tableNumber;
  final String orderDate;
  final String orderTime;
  final String itemNames;
  final String? cancelTime;

  CancelKotReport({
    required this.kotId,
    required this.quantity,
    required this.amount,
    required this.status,
    required this.notes,
    required this.tableNumber,
    required this.orderDate,
    required this.orderTime,
    required this.itemNames,
    required this.cancelTime,
  });

  factory CancelKotReport.fromJson(Map<String, dynamic> json) {
    String? amtRaw = json['amount']?.toString();
    double? parsedAmt = amtRaw != null ? double.tryParse(amtRaw) : null;
    return CancelKotReport(
      kotId: json['kot_ID'] ?? '',
      quantity: double.tryParse(json['quantity']?.toString() ?? '0') ?? 0.0,
      amount: parsedAmt != null ? parsedAmt.toStringAsFixed(3) : amtRaw,
      status: json['status'] ?? '',
      notes: json['notes'],
      tableNumber: json['table_Number'] ?? '',
      orderDate: json['order_Date'] ?? '',
      orderTime: json['order_Time'] ?? '',
      itemNames: json['item_Names'] ?? '',
      cancelTime: json['cancel_Time'],
    );
  }
}

class ItemConsumReport {
  final String productCode;
  final String productName;
  final String categoryName;
  final double saleQty;
  final double complimentaryQty;
  final double? noChargeQty;
  final double totalQty;
  final String totalAmount;
  final String discountPercent;
  final String discountAmount;
  final String amountAfterDiscount;
  final double homeDeliverySaleQty;
  final double dineInSaleQty;
  final double takeAwaySaleQty;
  final double onlineSaleQty;
  final double counterSaleQty;

  ItemConsumReport({
    required this.productCode,
    required this.productName,
    required this.categoryName,
    required this.saleQty,
    required this.complimentaryQty,
    required this.noChargeQty,
    required this.totalQty,
    required this.totalAmount,
    required this.discountPercent,
    required this.discountAmount,
    required this.amountAfterDiscount,
    required this.homeDeliverySaleQty,
    required this.dineInSaleQty,
    required this.takeAwaySaleQty,
    required this.onlineSaleQty,
    required this.counterSaleQty,
  });

  factory ItemConsumReport.fromJson(Map<String, dynamic> json) {
    double parse(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0.0;
    String fmt(dynamic v) {
      double? d = double.tryParse(v?.toString() ?? '');
      return d != null ? d.toStringAsFixed(3) : (v?.toString() ?? '0.000');
    }
    return ItemConsumReport(
      productCode: json['productCode']?.toString() ?? '',
      productName: json['productName']?.toString() ?? '',
      categoryName: json['categoryName']?.toString() ?? '',
      saleQty: parse(json['saleQty']),
      complimentaryQty: parse(json['complimentaryQty']),
      noChargeQty: json['noChargeQty'] != null ? parse(json['noChargeQty']) : null,
      totalQty: parse(json['totalQty']),
      totalAmount: fmt(json['totalAmount']),
      discountPercent: fmt(json['discountPercent']),
      discountAmount: fmt(json['discountAmount']),
      amountAfterDiscount: fmt(json['amountAfterDiscount']),
      homeDeliverySaleQty: parse(json['homeDeliverySaleQty']),
      dineInSaleQty: parse(json['dineInSaleQty']),
      takeAwaySaleQty: parse(json['takeAwaySaleQty']),
      onlineSaleQty: parse(json['onlineSaleQty']),
      counterSaleQty: parse(json['counterSaleQty']),
    );
  }
}

class MoveKotReport {
  final String kotId;
  final double qty;
  final String reason;
  final String? user;
  final String cancelDate;
  final String rate;
  final String waiterName;
  final String product;

  MoveKotReport({
    required this.kotId,
    required this.qty,
    required this.reason,
    required this.user,
    required this.cancelDate,
    required this.rate,
    required this.waiterName,
    required this.product,
  });

  factory MoveKotReport.fromJson(Map<String, dynamic> json) {
    String rateRaw = json['rate']?.toString() ?? '0.000';
    double? parsedRate = double.tryParse(rateRaw);
    return MoveKotReport(
      kotId: json['kotId']?.toString() ?? '',
      qty: double.tryParse(json['qty']?.toString() ?? '0') ?? 0.0,
      reason: json['reason']?.toString() ?? '',
      user: json['user']?.toString(),
      cancelDate: json['cancelDate']?.toString() ?? '',
      rate: parsedRate != null ? parsedRate.toStringAsFixed(3) : rateRaw,
      waiterName: json['waiterName']?.toString() ?? '',
      product: json['product']?.toString() ?? '',
    );
  }
}

class ComplimentReport {
  final String billNo;
  final String billDate;
  final String billAmount;
  final String? remark;
  final String waiter;

  ComplimentReport({
    required this.billNo,
    required this.billDate,
    required this.billAmount,
    required this.remark,
    required this.waiter,
  });

  factory ComplimentReport.fromJson(Map<String, dynamic> json) {
    String amtRaw = json['billAmount']?.toString() ?? '0.000';
    double? parsedAmt = double.tryParse(amtRaw);
    return ComplimentReport(
      billNo: json['billNo']?.toString() ?? '',
      billDate: json['billDate']?.toString() ?? '',
      billAmount: parsedAmt != null ? parsedAmt.toStringAsFixed(3) : amtRaw,
      remark: json['remark']?.toString(),
      waiter: json['waiter']?.toString() ?? '',
    );
  }
}