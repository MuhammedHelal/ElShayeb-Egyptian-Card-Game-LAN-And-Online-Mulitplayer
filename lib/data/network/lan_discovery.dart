/// Data Layer - LAN Room Discovery
///
/// Uses UDP broadcast to discover game rooms on the local network.
/// This is more reliable than mDNS on most Android devices.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import '../../domain/entities/room_info.dart';

/// Callback for discovered rooms
typedef RoomDiscoveredCallback = void Function(RoomInfo room);

/// LAN room discovery using UDP broadcast
class LanDiscovery {
  static const int discoveryPort = 41234;
  static const String broadcastMessage = 'ELSHAYEB_DISCOVER';
  static const Duration broadcastInterval = Duration(seconds: 2);
  static const Duration roomTimeout = Duration(seconds: 10);

  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  Timer? _cleanupTimer;

  final Map<String, RoomInfo> _discoveredRooms = {};
  final Map<String, DateTime> _roomLastSeen = {};

  RoomDiscoveredCallback? onRoomDiscovered;
  void Function(List<RoomInfo> rooms)? onRoomsUpdated;

  bool _isDiscovering = false;
  bool _isAdvertising = false;
  RoomInfo? _advertisedRoom;

  bool get isDiscovering => _isDiscovering;
  bool get isAdvertising => _isAdvertising;

  List<RoomInfo> get discoveredRooms => _discoveredRooms.values.toList();

  /// Start advertising a room (host)
  Future<void> startAdvertising(RoomInfo room) async {
    _advertisedRoom = room;

    if (_isAdvertising) return;

    try {
      _socket =
          await RawDatagramSocket.bind(InternetAddress.anyIPv4, discoveryPort);
      _socket!.broadcastEnabled = true;

      _socket!.listen(_handleDatagram);

      _isAdvertising = true;
      log('LAN Discovery: Advertising room ${room.roomCode} on port $discoveryPort');
    } catch (e) {
      log('LAN Discovery: Failed to start advertising: $e');
      // Try alternative port
      try {
        _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
        _socket!.broadcastEnabled = true;
        _socket!.listen(_handleDatagram);
        _isAdvertising = true;
        log('LAN Discovery: Advertising on alternative port ${_socket!.port}');
      } catch (e2) {
        log('LAN Discovery: Failed completely: $e2');
      }
    }
  }

  /// Stop advertising
  void stopAdvertising() {
    _isAdvertising = false;
    _advertisedRoom = null;
  }

  /// Start discovering rooms on the network
  Future<void> startDiscovery() async {
    if (_isDiscovering) return;

    try {
      _socket ??=
          await RawDatagramSocket.bind(InternetAddress.anyIPv4, discoveryPort);
      _socket!.broadcastEnabled = true;

      _socket!.listen(_handleDatagram);

      // Send discovery broadcasts periodically
      _broadcastTimer =
          Timer.periodic(broadcastInterval, (_) => _sendDiscoveryBroadcast());

      // Cleanup old rooms periodically
      _cleanupTimer =
          Timer.periodic(const Duration(seconds: 5), (_) => _cleanupOldRooms());

      // Send initial broadcast
      _sendDiscoveryBroadcast();

      _isDiscovering = true;
      log('LAN Discovery: Started discovering rooms');
    } catch (e) {
      log('LAN Discovery: Failed to start discovery: $e');
      // Try with alternative port
      try {
        _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
        _socket!.broadcastEnabled = true;
        _socket!.listen(_handleDatagram);

        _broadcastTimer =
            Timer.periodic(broadcastInterval, (_) => _sendDiscoveryBroadcast());
        _cleanupTimer = Timer.periodic(
            const Duration(seconds: 5), (_) => _cleanupOldRooms());
        _sendDiscoveryBroadcast();

        _isDiscovering = true;
      } catch (e2) {
        log('LAN Discovery: Failed completely: $e2');
      }
    }
  }

  /// Stop discovering
  void stopDiscovery() {
    _isDiscovering = false;
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _discoveredRooms.clear();
    _roomLastSeen.clear();
  }

  /// Send a discovery broadcast
  void _sendDiscoveryBroadcast() {
    if (_socket == null) return;

    try {
      final message = utf8.encode(broadcastMessage);

      // Send to broadcast address
      _socket!.send(message, InternetAddress('255.255.255.255'), discoveryPort);

      // Also try common subnet broadcasts
      _getLocalIpAddresses().then((addresses) {
        for (final addr in addresses) {
          final parts = addr.split('.');
          if (parts.length == 4) {
            final broadcast = '${parts[0]}.${parts[1]}.${parts[2]}.255';
            _socket!.send(message, InternetAddress(broadcast), discoveryPort);
          }
        }
      });
    } catch (e) {
      log('LAN Discovery: Broadcast error: $e');
    }
  }

  /// Handle incoming datagram
  void _handleDatagram(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;

    final datagram = _socket!.receive();
    if (datagram == null) return;

    try {
      final message = utf8.decode(datagram.data);

      if (message == broadcastMessage) {
        // This is a discovery request - respond if we're advertising
        if (_isAdvertising && _advertisedRoom != null) {
          _sendRoomInfo(datagram.address);
        }
      } else if (message.startsWith('{')) {
        // This is a room info response
        final json = jsonDecode(message) as Map<String, dynamic>;
        final room = RoomInfo.fromJson(json);

        // Update room address from the datagram source
        final updatedRoom = RoomInfo(
          roomId: room.roomId,
          roomCode: room.roomCode,
          hostName: room.hostName,
          hostAddress: datagram.address.address,
          port: room.port,
          playerCount: room.playerCount,
          maxPlayers: room.maxPlayers,
          isStarted: room.isStarted,
        );

        _discoveredRooms[updatedRoom.roomId] = updatedRoom;
        _roomLastSeen[updatedRoom.roomId] = DateTime.now();

        onRoomDiscovered?.call(updatedRoom);
        onRoomsUpdated?.call(discoveredRooms);
      }
    } catch (e) {
      // Ignore malformed messages
    }
  }

  /// Send room info as response
  void _sendRoomInfo(InternetAddress target) {
    if (_socket == null || _advertisedRoom == null) return;

    try {
      final json = jsonEncode(_advertisedRoom!.toJson());
      final data = utf8.encode(json);
      _socket!.send(data, target, discoveryPort);
    } catch (e) {
      log('LAN Discovery: Failed to send room info: $e');
    }
  }

  /// Remove rooms that haven't been seen recently
  void _cleanupOldRooms() {
    final now = DateTime.now();
    final toRemove = <String>[];

    _roomLastSeen.forEach((id, lastSeen) {
      if (now.difference(lastSeen) > roomTimeout) {
        toRemove.add(id);
      }
    });

    for (final id in toRemove) {
      _discoveredRooms.remove(id);
      _roomLastSeen.remove(id);
    }

    if (toRemove.isNotEmpty) {
      onRoomsUpdated?.call(discoveredRooms);
    }
  }

  /// Get local IP addresses
  Future<List<String>> _getLocalIpAddresses() async {
    final addresses = <String>[];

    try {
      for (final interface in await NetworkInterface.list()) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            addresses.add(addr.address);
          }
        }
      }
    } catch (e) {
      log('LAN Discovery: Failed to get local IPs: $e');
    }

    return addresses;
  }

  /// Get the local IP address for display
  Future<String?> getLocalIpAddress() async {
    final addresses = await _getLocalIpAddresses();
    return addresses.isNotEmpty ? addresses.first : null;
  }

  /// Dispose resources
  void dispose() {
    stopDiscovery();
    stopAdvertising();
    _socket?.close();
    _socket = null;
  }
}
