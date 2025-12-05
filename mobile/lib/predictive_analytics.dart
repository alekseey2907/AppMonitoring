import 'dart:math';

/// Система предиктивного мониторинга VibeMon
/// 
/// Функции:
/// 1. Обучение на "здоровых" данных (baseline)
/// 2. Детекция аномалий в реальном времени
/// 3. Трендовый анализ (ухудшение состояния)
/// 4. Прогнозирование времени до отказа (RUL)
/// 5. Классификация типов дефектов

class PredictiveAnalytics {
  // Baseline параметры (обученные на "здоровом" оборудовании)
  BaselineModel? _baseline;
  
  // История для трендового анализа
  final List<HealthSnapshot> _healthHistory = [];
  static const int maxHistorySize = 1000;
  
  // Состояние системы
  bool get isTrained => _baseline != null;
  int get historySize => _healthHistory.length;

  /// Обучение baseline на нормальных данных
  void trainBaseline(List<VibrationSample> normalSamples) {
    if (normalSamples.length < 30) {
      throw Exception('Нужно минимум 30 сэмплов для обучения');
    }

    // Статистика по каждому параметру
    final rmsValues = normalSamples.map((s) => s.rms).toList();
    final velocityValues = normalSamples.map((s) => s.rmsVelocity).toList();
    final peakValues = normalSamples.map((s) => s.peak).toList();
    final cfValues = normalSamples.map((s) => s.crestFactor).toList();
    final freqValues = normalSamples.map((s) => s.dominantFreq).toList();
    final tempValues = normalSamples.map((s) => s.temperature).toList();

    _baseline = BaselineModel(
      rms: _calculateStats(rmsValues),
      rmsVelocity: _calculateStats(velocityValues),
      peak: _calculateStats(peakValues),
      crestFactor: _calculateStats(cfValues),
      dominantFreq: _calculateStats(freqValues),
      temperature: _calculateStats(tempValues),
      trainedAt: DateTime.now(),
      sampleCount: normalSamples.length,
    );
  }

  ParameterStats _calculateStats(List<double> values) {
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) / values.length;
    final stdDev = sqrt(variance);
    final sorted = List<double>.from(values)..sort();
    final median = sorted[sorted.length ~/ 2];
    final min = sorted.first;
    final max = sorted.last;
    final p95 = sorted[(sorted.length * 0.95).floor()];
    final p99 = sorted[(sorted.length * 0.99).floor()];
    
    return ParameterStats(
      mean: mean,
      stdDev: stdDev,
      median: median,
      min: min,
      max: max,
      p95: p95,
      p99: p99,
    );
  }

  /// Анализ текущего состояния
  HealthAnalysis analyze(VibrationSample sample) {
    if (_baseline == null) {
      return HealthAnalysis(
        overallHealth: 100,
        anomalyScore: 0,
        anomalies: [],
        diagnosis: 'Baseline не обучен',
        recommendation: 'Запишите данные при нормальной работе и обучите baseline',
        predictedRUL: null,
        trend: TrendDirection.unknown,
      );
    }

    final anomalies = <AnomalyDetail>[];
    double totalAnomalyScore = 0;

    // Проверка каждого параметра
    final checks = [
      _checkParameter('RMS', sample.rms, _baseline!.rms, 3.0),
      _checkParameter('Скорость RMS', sample.rmsVelocity, _baseline!.rmsVelocity, 3.0),
      _checkParameter('Пик', sample.peak, _baseline!.peak, 3.5),
      _checkParameter('Crest Factor', sample.crestFactor, _baseline!.crestFactor, 2.5),
      _checkParameter('Частота', sample.dominantFreq, _baseline!.dominantFreq, 4.0),
      _checkParameter('Температура', sample.temperature, _baseline!.temperature, 3.0),
    ];

    for (final check in checks) {
      if (check != null) {
        anomalies.add(check);
        totalAnomalyScore += check.severity;
      }
    }

    // Нормализуем score (0-100)
    final anomalyScore = (totalAnomalyScore / checks.length * 25).clamp(0.0, 100.0);
    final overallHealth = (100 - anomalyScore).clamp(0.0, 100.0);

    // Добавляем в историю
    final snapshot = HealthSnapshot(
      timestamp: DateTime.now(),
      health: overallHealth,
      rms: sample.rms,
      rmsVelocity: sample.rmsVelocity,
      crestFactor: sample.crestFactor,
      temperature: sample.temperature,
    );
    _healthHistory.add(snapshot);
    if (_healthHistory.length > maxHistorySize) {
      _healthHistory.removeAt(0);
    }

    // Трендовый анализ
    final trend = _analyzeTrend();
    
    // Прогноз RUL (Remaining Useful Life)
    final rul = _predictRUL(overallHealth, trend);

    // Диагностика и рекомендации
    final diagResult = _diagnose(sample, anomalies, trend);

    return HealthAnalysis(
      overallHealth: overallHealth,
      anomalyScore: anomalyScore,
      anomalies: anomalies,
      diagnosis: diagResult.diagnosis,
      recommendation: diagResult.recommendation,
      predictedRUL: rul,
      trend: trend,
      defectType: diagResult.defectType,
    );
  }

  AnomalyDetail? _checkParameter(
    String name, 
    double value, 
    ParameterStats baseline, 
    double threshold,
  ) {
    if (baseline.stdDev == 0) return null;
    
    final zScore = (value - baseline.mean).abs() / baseline.stdDev;
    
    if (zScore > threshold) {
      final severity = ((zScore - threshold) / threshold * 2).clamp(0.0, 4.0);
      final direction = value > baseline.mean ? 'повышен' : 'понижен';
      
      return AnomalyDetail(
        parameter: name,
        value: value,
        baseline: baseline.mean,
        zScore: zScore,
        severity: severity,
        description: '$name $direction (${zScore.toStringAsFixed(1)}σ от нормы)',
      );
    }
    return null;
  }

  TrendDirection _analyzeTrend() {
    if (_healthHistory.length < 10) return TrendDirection.unknown;

    // Берём последние 50 записей или все что есть
    final recent = _healthHistory.length > 50 
        ? _healthHistory.sublist(_healthHistory.length - 50) 
        : _healthHistory;

    // Линейная регрессия для определения тренда
    final n = recent.length;
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    
    for (int i = 0; i < n; i++) {
      sumX += i;
      sumY += recent[i].health;
      sumXY += i * recent[i].health;
      sumX2 += i * i;
    }

    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    
    // Интерпретация наклона
    if (slope < -0.5) return TrendDirection.degradingFast;
    if (slope < -0.1) return TrendDirection.degrading;
    if (slope > 0.5) return TrendDirection.improvingFast;
    if (slope > 0.1) return TrendDirection.improving;
    return TrendDirection.stable;
  }

  Duration? _predictRUL(double currentHealth, TrendDirection trend) {
    if (_healthHistory.length < 20) return null;
    if (trend == TrendDirection.stable || 
        trend == TrendDirection.improving ||
        trend == TrendDirection.improvingFast ||
        trend == TrendDirection.unknown) {
      return null; // Нет деградации - RUL не применим
    }

    // Рассчитываем скорость деградации
    final recent = _healthHistory.sublist(_healthHistory.length - 20);
    final firstHealth = recent.first.health;
    final lastHealth = recent.last.health;
    final timeDiff = recent.last.timestamp.difference(recent.first.timestamp);
    
    if (timeDiff.inMinutes == 0 || lastHealth >= firstHealth) return null;

    final degradationRate = (firstHealth - lastHealth) / timeDiff.inMinutes; // %/мин
    
    if (degradationRate <= 0) return null;

    // Критический порог - 30% здоровья
    const criticalThreshold = 30.0;
    final healthToLose = currentHealth - criticalThreshold;
    
    if (healthToLose <= 0) {
      return Duration.zero; // Уже в критическом состоянии
    }

    final minutesToFailure = healthToLose / degradationRate;
    return Duration(minutes: minutesToFailure.round());
  }

  DiagnosisResult _diagnose(
    VibrationSample sample, 
    List<AnomalyDetail> anomalies,
    TrendDirection trend,
  ) {
    // Классификация дефекта по характерным признакам
    DefectType? defectType;
    String diagnosis = '';
    String recommendation = '';

    if (anomalies.isEmpty) {
      diagnosis = 'Оборудование в норме';
      recommendation = 'Продолжайте регулярный мониторинг';
      return DiagnosisResult(diagnosis, recommendation, null);
    }

    final hasHighCF = anomalies.any((a) => 
        a.parameter == 'Crest Factor' && sample.crestFactor > 4);
    final hasHighRMS = anomalies.any((a) => a.parameter == 'RMS');
    final hasHighVelocity = anomalies.any((a) => a.parameter == 'Скорость RMS');
    final hasHighTemp = anomalies.any((a) => a.parameter == 'Температура');
    final freqAnomaly = anomalies.firstWhere(
      (a) => a.parameter == 'Частота', 
      orElse: () => AnomalyDetail(parameter: '', value: 0, baseline: 0, zScore: 0, severity: 0, description: ''),
    );

    // Логика классификации дефектов
    if (hasHighCF && sample.crestFactor > 6) {
      defectType = DefectType.bearingDefect;
      diagnosis = 'Вероятный дефект подшипника (ранняя стадия)';
      recommendation = 'Запланируйте замену подшипника в ближайшие 2-4 недели';
    } else if (hasHighRMS && sample.dominantFreq > 0 && sample.dominantFreq < 30) {
      defectType = DefectType.imbalance;
      diagnosis = 'Дисбаланс ротора';
      recommendation = 'Требуется балансировка. Проверьте крепление и износ';
    } else if (hasHighVelocity && sample.dominantFreq >= 80 && sample.dominantFreq <= 120) {
      defectType = DefectType.misalignment;
      diagnosis = 'Несоосность валов (2x гармоника)';
      recommendation = 'Проверьте центровку валов и состояние муфты';
    } else if (hasHighTemp && !hasHighRMS) {
      defectType = DefectType.lubrication;
      diagnosis = 'Проблема смазки или охлаждения';
      recommendation = 'Проверьте уровень и качество смазки';
    } else if (hasHighRMS && hasHighTemp) {
      defectType = DefectType.overload;
      diagnosis = 'Перегрузка или износ механизма';
      recommendation = 'Снизьте нагрузку, проверьте механизм на износ';
    } else if (freqAnomaly.severity > 0 && sample.dominantFreq > 200) {
      defectType = DefectType.gearDefect;
      diagnosis = 'Возможный дефект зубчатой передачи';
      recommendation = 'Проверьте состояние шестерён';
    } else {
      defectType = DefectType.unknown;
      diagnosis = 'Обнаружены отклонения от нормы';
      recommendation = 'Требуется детальная диагностика специалистом';
    }

    // Дополнение по тренду
    if (trend == TrendDirection.degradingFast) {
      recommendation += '\n⚠️ ВНИМАНИЕ: Быстрая деградация! Требуется срочное вмешательство.';
    } else if (trend == TrendDirection.degrading) {
      recommendation += '\n📉 Состояние ухудшается. Запланируйте ТО.';
    }

    return DiagnosisResult(diagnosis, recommendation, defectType);
  }

  /// Экспорт baseline для сохранения
  Map<String, dynamic>? exportBaseline() {
    if (_baseline == null) return null;
    return _baseline!.toJson();
  }

  /// Импорт baseline
  void importBaseline(Map<String, dynamic> json) {
    _baseline = BaselineModel.fromJson(json);
  }

  /// Сброс системы
  void reset() {
    _baseline = null;
    _healthHistory.clear();
  }

  /// Получить историю здоровья для графика
  List<HealthSnapshot> getHealthHistory() => List.from(_healthHistory);
}

// ==================== МОДЕЛИ ДАННЫХ ====================

class VibrationSample {
  final double rms;
  final double rmsVelocity;
  final double peak;
  final double peakToPeak;
  final double crestFactor;
  final double dominantFreq;
  final double temperature;
  final DateTime timestamp;

  VibrationSample({
    required this.rms,
    required this.rmsVelocity,
    required this.peak,
    required this.peakToPeak,
    required this.crestFactor,
    required this.dominantFreq,
    required this.temperature,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class ParameterStats {
  final double mean;
  final double stdDev;
  final double median;
  final double min;
  final double max;
  final double p95;
  final double p99;

  ParameterStats({
    required this.mean,
    required this.stdDev,
    required this.median,
    required this.min,
    required this.max,
    required this.p95,
    required this.p99,
  });

  Map<String, dynamic> toJson() => {
    'mean': mean, 'stdDev': stdDev, 'median': median,
    'min': min, 'max': max, 'p95': p95, 'p99': p99,
  };

  factory ParameterStats.fromJson(Map<String, dynamic> json) => ParameterStats(
    mean: json['mean'], stdDev: json['stdDev'], median: json['median'],
    min: json['min'], max: json['max'], p95: json['p95'], p99: json['p99'],
  );
}

class BaselineModel {
  final ParameterStats rms;
  final ParameterStats rmsVelocity;
  final ParameterStats peak;
  final ParameterStats crestFactor;
  final ParameterStats dominantFreq;
  final ParameterStats temperature;
  final DateTime trainedAt;
  final int sampleCount;

  BaselineModel({
    required this.rms,
    required this.rmsVelocity,
    required this.peak,
    required this.crestFactor,
    required this.dominantFreq,
    required this.temperature,
    required this.trainedAt,
    required this.sampleCount,
  });

  Map<String, dynamic> toJson() => {
    'rms': rms.toJson(),
    'rmsVelocity': rmsVelocity.toJson(),
    'peak': peak.toJson(),
    'crestFactor': crestFactor.toJson(),
    'dominantFreq': dominantFreq.toJson(),
    'temperature': temperature.toJson(),
    'trainedAt': trainedAt.toIso8601String(),
    'sampleCount': sampleCount,
  };

  factory BaselineModel.fromJson(Map<String, dynamic> json) => BaselineModel(
    rms: ParameterStats.fromJson(json['rms']),
    rmsVelocity: ParameterStats.fromJson(json['rmsVelocity']),
    peak: ParameterStats.fromJson(json['peak']),
    crestFactor: ParameterStats.fromJson(json['crestFactor']),
    dominantFreq: ParameterStats.fromJson(json['dominantFreq']),
    temperature: ParameterStats.fromJson(json['temperature']),
    trainedAt: DateTime.parse(json['trainedAt']),
    sampleCount: json['sampleCount'],
  );
}

class HealthSnapshot {
  final DateTime timestamp;
  final double health;
  final double rms;
  final double rmsVelocity;
  final double crestFactor;
  final double temperature;

  HealthSnapshot({
    required this.timestamp,
    required this.health,
    required this.rms,
    required this.rmsVelocity,
    required this.crestFactor,
    required this.temperature,
  });
}

class AnomalyDetail {
  final String parameter;
  final double value;
  final double baseline;
  final double zScore;
  final double severity; // 0-4
  final String description;

  AnomalyDetail({
    required this.parameter,
    required this.value,
    required this.baseline,
    required this.zScore,
    required this.severity,
    required this.description,
  });
}

class HealthAnalysis {
  final double overallHealth; // 0-100%
  final double anomalyScore; // 0-100
  final List<AnomalyDetail> anomalies;
  final String diagnosis;
  final String recommendation;
  final Duration? predictedRUL; // Remaining Useful Life
  final TrendDirection trend;
  final DefectType? defectType;

  HealthAnalysis({
    required this.overallHealth,
    required this.anomalyScore,
    required this.anomalies,
    required this.diagnosis,
    required this.recommendation,
    required this.predictedRUL,
    required this.trend,
    this.defectType,
  });

  String get healthStatus {
    if (overallHealth >= 80) return 'Отлично';
    if (overallHealth >= 60) return 'Хорошо';
    if (overallHealth >= 40) return 'Внимание';
    if (overallHealth >= 20) return 'Тревога';
    return 'Критично';
  }

  String get rulFormatted {
    if (predictedRUL == null) return 'Н/Д';
    if (predictedRUL == Duration.zero) return 'Критично!';
    
    final hours = predictedRUL!.inHours;
    final days = predictedRUL!.inDays;
    
    if (days > 30) return '> 30 дней';
    if (days > 0) return '$days дн. ${hours % 24} ч.';
    if (hours > 0) return '$hours ч. ${predictedRUL!.inMinutes % 60} мин.';
    return '${predictedRUL!.inMinutes} мин.';
  }
}

class DiagnosisResult {
  final String diagnosis;
  final String recommendation;
  final DefectType? defectType;

  DiagnosisResult(this.diagnosis, this.recommendation, this.defectType);
}

enum TrendDirection {
  unknown,
  stable,
  improving,
  improvingFast,
  degrading,
  degradingFast,
}

enum DefectType {
  unknown,
  imbalance,      // Дисбаланс
  misalignment,   // Несоосность
  bearingDefect,  // Дефект подшипника
  gearDefect,     // Дефект шестерён
  looseness,      // Ослабление
  lubrication,    // Проблема смазки
  overload,       // Перегрузка
}

extension TrendDirectionExt on TrendDirection {
  String get name {
    switch (this) {
      case TrendDirection.unknown: return 'Недостаточно данных';
      case TrendDirection.stable: return 'Стабильно';
      case TrendDirection.improving: return 'Улучшается';
      case TrendDirection.improvingFast: return 'Быстро улучшается';
      case TrendDirection.degrading: return 'Ухудшается';
      case TrendDirection.degradingFast: return 'Быстро ухудшается';
    }
  }

  String get icon {
    switch (this) {
      case TrendDirection.unknown: return '❓';
      case TrendDirection.stable: return '➡️';
      case TrendDirection.improving: return '📈';
      case TrendDirection.improvingFast: return '🚀';
      case TrendDirection.degrading: return '📉';
      case TrendDirection.degradingFast: return '⚠️';
    }
  }
}

extension DefectTypeExt on DefectType {
  String get name {
    switch (this) {
      case DefectType.unknown: return 'Неизвестный дефект';
      case DefectType.imbalance: return 'Дисбаланс';
      case DefectType.misalignment: return 'Несоосность';
      case DefectType.bearingDefect: return 'Дефект подшипника';
      case DefectType.gearDefect: return 'Дефект шестерён';
      case DefectType.looseness: return 'Ослабление';
      case DefectType.lubrication: return 'Проблема смазки';
      case DefectType.overload: return 'Перегрузка';
    }
  }

  String get icon {
    switch (this) {
      case DefectType.unknown: return '❓';
      case DefectType.imbalance: return '⚖️';
      case DefectType.misalignment: return '↔️';
      case DefectType.bearingDefect: return '🔴';
      case DefectType.gearDefect: return '⚙️';
      case DefectType.looseness: return '🔩';
      case DefectType.lubrication: return '🛢️';
      case DefectType.overload: return '⚡';
    }
  }
}
