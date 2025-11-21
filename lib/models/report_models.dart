// lib/models/report_models.dart

class ProductionReport {
  final DateTime startDate;
  final DateTime endDate;
  final List<SectorReportData> sectorData;
  final int totalProducedInRange;
  final int totalCurrentlyInProduction;

  ProductionReport({
    required this.startDate,
    required this.endDate,
    required this.sectorData,
    required this.totalProducedInRange,
    required this.totalCurrentlyInProduction,
  });
}

class SectorReportData {
  final String sectorId;
  final String sectorName;
  final int producedInRange;
  final List<Map<String, dynamic>> finalizedFichasInRange;
  final int currentlyInProduction;
  final List<Map<String, dynamic>> openFichas;

  SectorReportData({
    required this.sectorId,
    required this.sectorName,
    required this.producedInRange,
    required this.finalizedFichasInRange,
    required this.currentlyInProduction,
    required this.openFichas,
  });
}

class BottleneckReport {
  final DateTime startDate;
  final DateTime endDate;
  final List<BottleneckSummaryItem> summary;
  final List<Map<String, dynamic>> rawData;

  BottleneckReport({
    required this.startDate,
    required this.endDate,
    required this.summary,
    required this.rawData,
  });
}

class BottleneckSummaryItem {
  final String reason;
  int count;
  Duration totalDuration;

  BottleneckSummaryItem({
    required this.reason,
    this.count = 0,
    this.totalDuration = Duration.zero,
  });
}
