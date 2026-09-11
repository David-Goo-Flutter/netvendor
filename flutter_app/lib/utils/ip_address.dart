/// ARP only maps IPv4 addresses, so that is all this app deals with.
final _ipv4Octet = r'(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)';
final _ipv4 = RegExp('^$_ipv4Octet(\\.$_ipv4Octet){3}\$');

bool isValidIPv4Address(String value) => _ipv4.hasMatch(value.trim());
