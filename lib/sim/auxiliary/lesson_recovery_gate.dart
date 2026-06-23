import 'recovery_room_service.dart';

bool isFinalBlockedByRecovery(
  RecoveryRoomService recoveryRoomService,
  String lessonLocalId,
) {
  return recoveryRoomService.shouldStartRecoveryRoom(lessonLocalId);
}
