
// Go言語の構造体に合わせて定義します

class Activity {
  final int? id;
  final String userId;
  final String category; // 'mahjong', 'golf'
  final DateTime playedAt;
  final String placeName;
  final String summaryText;
  final int primaryScore;
  final List<String> imageUrls;
  final MahjongData? mahjongData;

  Activity({
    this.id,
    required this.userId,
    required this.category,
    required this.playedAt,
    this.placeName = '',
    this.summaryText = '',
    this.primaryScore = 0,
    this.imageUrls = const [],
    this.mahjongData,
  });

  // サーバーに送るためにJSONに変換
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'category': category,
      'played_at': playedAt.toUtc().toIso8601String(),
      'place_name': placeName,
      'summary_text': summaryText,
      'primary_score': primaryScore,
      'image_urls': imageUrls,
      if (mahjongData != null) 'mahjong_data': mahjongData!.toJson(),
    };
  }
}

class MahjongData {
  final int playerCount;
  final List<String> playerNames;
  final int hasChip;
  final List<int> chips;
  final List<MahjongRound> rounds;
  final List<MahjongYakuman> yakumans;

  MahjongData({
    required this.playerCount,
    required this.playerNames,
    required this.hasChip,
    required this.chips,
    required this.rounds,
    required this.yakumans,
  });

  Map<String, dynamic> toJson() {
    return {
      'player_count': playerCount,
      'player_names': playerNames,
      'has_chip': hasChip,
      'chips': chips,
      'rounds': rounds.map((r) => r.toJson()).toList(),
      'yakumans': yakumans.map((y) => y.toJson()).toList(),
    };
  }
}

class MahjongRound {
  final int roundNumber;
  final List<int> scores;

  MahjongRound({required this.roundNumber, required this.scores});

  Map<String, dynamic> toJson() => {
    'round_number': roundNumber,
    'scores': scores,
  };
}

class MahjongYakuman {
  final int roundNumber;
  final int playerIndex;
  final String yakumanName;
  final String imagePath;

  MahjongYakuman({
    required this.roundNumber,
    required this.playerIndex,
    required this.yakumanName,
    required this.imagePath,
  });

  Map<String, dynamic> toJson() => {
    'round_number': roundNumber,
    'player_index': playerIndex,
    'yakuman_name': yakumanName,
    'image_path': imagePath,
  };
}