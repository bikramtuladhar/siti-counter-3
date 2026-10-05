/// Siti Counter 3.0 - Multi-Dish Kitchen Engine (Section 10.6)
/// Simultaneous multi-cooker management, parallel cooking lanes,
/// burner & vessel conflict detection, and acoustic whistle disambiguation.
library;

enum CookerVesselType {
  pressureCooker5L,
  pressureCooker3L,
  kadaiPan,
  saucepan,
  tawa,
  electricRiceCooker,
  kettle,
}

enum LaneStatus {
  cooking,
  waiting,
  paused,
  completed,
}

class CookingLane {
  final String id;
  final String dishName;
  final String dishNameNe;
  final CookerVesselType vesselType;
  final String vesselId;
  final bool requiresBurner;
  final int? burnerIndex;
  LaneStatus status;
  bool isAcousticCooker;
  int currentWhistles;
  int targetWhistles;
  int remainingSeconds;
  int totalSeconds;
  String heatLevel;

  CookingLane({
    required this.id,
    required this.dishName,
    required this.dishNameNe,
    required this.vesselType,
    required this.vesselId,
    required this.requiresBurner,
    this.burnerIndex,
    this.status = LaneStatus.waiting,
    this.isAcousticCooker = false,
    this.currentWhistles = 0,
    this.targetWhistles = 0,
    this.remainingSeconds = 0,
    this.totalSeconds = 0,
    this.heatLevel = 'medium',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'dishName': dishName,
    'dishNameNe': dishNameNe,
    'vesselType': vesselType.name,
    'vesselId': vesselId,
    'requiresBurner': requiresBurner,
    'burnerIndex': burnerIndex,
    'status': status.name,
    'isAcousticCooker': isAcousticCooker,
    'currentWhistles': currentWhistles,
    'targetWhistles': targetWhistles,
    'remainingSeconds': remainingSeconds,
    'totalSeconds': totalSeconds,
    'heatLevel': heatLevel,
  };
}

enum MultiDishConflictType {
  burnerCapacity,
  vesselCollision,
}

class MultiDishConflict {
  final MultiDishConflictType type;
  final String messageEn;
  final String messageNe;
  final List<String> conflictingLaneIds;
  final String suggestionEn;
  final String suggestionNe;

  const MultiDishConflict({
    required this.type,
    required this.messageEn,
    required this.messageNe,
    required this.conflictingLaneIds,
    required this.suggestionEn,
    required this.suggestionNe,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'messageEn': messageEn,
    'messageNe': messageNe,
    'conflictingLaneIds': conflictingLaneIds,
    'suggestionEn': suggestionEn,
    'suggestionNe': suggestionNe,
  };
}

class WhistleDisambiguationRequest {
  final DateTime timestamp;
  final List<String> candidateLaneIds;
  final List<String> candidateDishNames;
  bool resolved;
  String? attributedLaneId;

  WhistleDisambiguationRequest({
    required this.timestamp,
    required this.candidateLaneIds,
    required this.candidateDishNames,
    this.resolved = false,
    this.attributedLaneId,
  });
}

class MultiDishKitchenEngine {
  final Map<String, CookingLane> _lanes = {};
  int _maxBurners;
  WhistleDisambiguationRequest? _pendingDisambiguation;

  MultiDishKitchenEngine({int maxBurners = 2})
      : _maxBurners = maxBurners > 0 ? maxBurners : 2;

  int get maxBurners => _maxBurners;

  set maxBurners(int burners) {
    if (burners > 0) _maxBurners = burners;
  }

  List<CookingLane> get lanes => _lanes.values.toList();

  CookingLane? getLane(String id) => _lanes[id];

  void addLane(CookingLane lane) {
    _lanes[lane.id] = lane;
  }

  bool removeLane(String id) {
    return _lanes.remove(id) != null;
  }

  void updateLaneStatus(String id, LaneStatus status) {
    final lane = _lanes[id];
    if (lane != null) {
      lane.status = status;
    }
  }

  List<MultiDishConflict> detectConflicts() {
    final conflicts = <MultiDishConflict>[];
    final activeLanes = _lanes.values
        .where((l) => l.status == LaneStatus.cooking)
        .toList();

    // 1. Burner capacity check
    final burnerLanes = activeLanes.where((l) => l.requiresBurner).toList();
    if (burnerLanes.length > _maxBurners) {
      final excess = burnerLanes.length - _maxBurners;
      conflicts.add(
        MultiDishConflict(
          type: MultiDishConflictType.burnerCapacity,
          messageEn:
              'Cooktop capacity exceeded: ${burnerLanes.length} dishes active on $_maxBurners burners.',
          messageNe:
              'चुल्होको क्षमता नाघ्यो: $_maxBurners बर्नरमा ${burnerLanes.length} परिकार पाक्दैछन्।',
          conflictingLaneIds: burnerLanes.map((l) => l.id).toList(),
          suggestionEn: 'Move $excess dish(es) to waiting status or cook ahead.',
          suggestionNe:
              '$excess परिकारलाई पर्खने सूचीमा राख्नुहोस् वा अगाडि नै पकाउनुहोस्।',
        ),
      );
    }

    // 2. Vessel collision check
    final vesselUsage = <String, List<String>>{};
    for (final lane in activeLanes) {
      vesselUsage.putIfAbsent(lane.vesselId, () => []).add(lane.id);
    }

    for (final entry in vesselUsage.entries) {
      if (entry.value.length > 1) {
        final laneNames = entry.value
            .map((id) => _lanes[id]?.dishName ?? id)
            .join(' & ');
        conflicts.add(
          MultiDishConflict(
            type: MultiDishConflictType.vesselCollision,
            messageEn:
                'Vessel conflict: Multiple dishes ($laneNames) assigned to the same vessel \'${entry.key}\'.',
            messageNe:
                'भाँडो जुधाइ: एउटै भाँडो (${entry.key}) धेरै परिकारहरू ($laneNames) मा प्रयोग गरिएको छ।',
            conflictingLaneIds: entry.value,
            suggestionEn:
                'Assign an alternate pot or finish one dish before starting the next.',
            suggestionNe:
                'अर्को भाँडो प्रयोग गर्नुहोस् वा पहिलेको परिकार पाकिसकेपछि सुरु गर्नुहोस्।',
          ),
        );
      }
    }

    return conflicts;
  }

  Map<String, dynamic> handleAcousticWhistle([DateTime? timestamp]) {
    final activeCookers = _lanes.values
        .where((l) => l.status == LaneStatus.cooking && l.isAcousticCooker)
        .toList();

    if (activeCookers.isEmpty) {
      return {'needsDisambiguation': false};
    }

    if (activeCookers.length == 1) {
      final cooker = activeCookers.first;
      cooker.currentWhistles += 1;
      if (cooker.currentWhistles >= cooker.targetWhistles && cooker.targetWhistles > 0) {
        cooker.status = LaneStatus.completed;
      }
      return {
        'attributedLaneId': cooker.id,
        'needsDisambiguation': false,
      };
    }

    // Multiple acoustic cookers active simultaneously
    final req = WhistleDisambiguationRequest(
      timestamp: timestamp ?? DateTime.now(),
      candidateLaneIds: activeCookers.map((c) => c.id).toList(),
      candidateDishNames: activeCookers.map((c) => c.dishName).toList(),
    );
    _pendingDisambiguation = req;

    return {
      'needsDisambiguation': true,
      'disambiguationRequest': req,
    };
  }

  WhistleDisambiguationRequest? get pendingDisambiguation => _pendingDisambiguation;

  bool resolveDisambiguation(String laneId) {
    if (_pendingDisambiguation == null ||
        !_pendingDisambiguation!.candidateLaneIds.contains(laneId)) {
      return false;
    }

    final lane = _lanes[laneId];
    if (lane != null) {
      lane.currentWhistles += 1;
      if (lane.currentWhistles >= lane.targetWhistles && lane.targetWhistles > 0) {
        lane.status = LaneStatus.completed;
      }
    }

    _pendingDisambiguation!.resolved = true;
    _pendingDisambiguation!.attributedLaneId = laneId;
    _pendingDisambiguation = null;
    return true;
  }

  void tickTimers(int deltaSeconds) {
    for (final lane in _lanes.values) {
      if (lane.status == LaneStatus.cooking && lane.remainingSeconds > 0) {
        lane.remainingSeconds = (lane.remainingSeconds - deltaSeconds).clamp(0, lane.totalSeconds);
        if (lane.remainingSeconds == 0 && !lane.isAcousticCooker) {
          lane.status = LaneStatus.completed;
        }
      }
    }
  }
}
