import 'aux_room_models.dart';

const Map<AuxRoomMode, String> auxRoomAddonReference = {
  AuxRoomMode.review: 'SIM_AUX_ADDON_REVIEW_SERVER_SIDE',
  AuxRoomMode.recovery: 'SIM_AUX_ADDON_RECOVERY_SERVER_SIDE',
  AuxRoomMode.doubt: 'ADENDO_DOUBT_SERVER_SIDE',
};

String getAuxRoomAddonReference(AuxRoomMode mode) => auxRoomAddonReference[mode]!;
