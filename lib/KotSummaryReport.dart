//no changes
class KotSummaryReport {
  final String? kotId;
  final String? orderType;
  final String? customerName;
  final String? customerPhone;
  final String? numberOfItems;
  final String? items;
  final String? kotStatus;
  final String? billPrintDate;
  final String? completeDuration;
  final String? created;
  final String? tableNo;

  KotSummaryReport({
    this.kotId,
    this.orderType,
    this.customerName,
    this.customerPhone,
    this.numberOfItems,
    this.items,
    this.kotStatus,
    this.billPrintDate,
    this.completeDuration,
    this.created,
    this.tableNo,
  });



  factory KotSummaryReport.fromJson(Map<String, dynamic> json) {
    return KotSummaryReport(
      kotId: json['kotId'] ?? '',
      orderType: json['orderType'] ?? '',
      customerName: json['customerName'] ?? '',
      customerPhone: json['customerPhone'] ?? '',
      numberOfItems: json['numberOfItems'] ?? '',
      items: json['items'] ?? '',
      kotStatus: json['kotStatus'] ?? '', tableNo: json['tableNo'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'kotId': kotId,
      'orderType': orderType,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'numberOfItems': numberOfItems,
      'items': items,
      'kotStatus': kotStatus,'tableNo': tableNo,
    };
  }
}