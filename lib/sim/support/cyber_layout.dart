class CyberLayoutContract {
  const CyberLayoutContract({
    required this.route,
    required this.ssr,
    required this.definesOwnHead,
    required this.behavior,
  });

  final String route;
  final bool ssr;
  final bool definesOwnHead;
  final String behavior;
}

const cyberLayoutContract = CyberLayoutContract(
  route: '/cyber',
  ssr: false,
  definesOwnHead: false,
  behavior: 'Outlet',
);
