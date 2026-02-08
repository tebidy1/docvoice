enum PairingStatus {
  idle,
  loading,
  authorized,
  expired,
  error,
}

class PairingSession {
  final String id;
  final String? shortCode;
  final int? expiresIn;
  final PairingStatus status;

  PairingSession({
    required this.id,
    this.shortCode,
    this.expiresIn,
    this.status = PairingStatus.idle,
  });
}
