class PlacementChoiceScreenModel {
  const PlacementChoiceScreenModel({
    this.titleKey = 'placement_choice_h1',
    this.bodyKey = 'placement_choice_body',
    this.startBeginningKey = 'placement_start_beginning',
    this.takeQuickKey = 'placement_take_quick',
  });

  final String titleKey;
  final String bodyKey;
  final String startBeginningKey;
  final String takeQuickKey;
}

class PlacementIntroScreenModel {
  const PlacementIntroScreenModel({
    this.titleKey = 'placement_intro_h1',
    this.bodyKey = 'placement_intro_body',
    this.startKey = 'placement_start',
    this.preparingKey = 'placement_preparing',
  });

  final String titleKey;
  final String bodyKey;
  final String startKey;
  final String preparingKey;
}

class PlacementQuestionScreenModel {
  const PlacementQuestionScreenModel({
    required this.questionOfKey,
    required this.prompt,
    required this.choiceLabels,
  });

  final String questionOfKey;
  final String prompt;
  final List<String> choiceLabels;
}

class PlacementResultScreenModel {
  const PlacementResultScreenModel({
    required this.startMarker,
    this.titleKey = 'placement_result_h1',
    this.bodyKey = 'placement_result_body',
    this.startingAtKey = 'placement_starting_at',
    this.continueKey = 'continue',
  });

  final String startMarker;
  final String titleKey;
  final String bodyKey;
  final String startingAtKey;
  final String continueKey;
}
