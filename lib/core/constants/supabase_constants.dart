/// Core - Supabase Constants
///
/// Configuration for Supabase connection.
///
library;

class SupabaseConstants {
  static const String url = 'https://cusfjqfiurvekppweuaq.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN1c2ZqcWZpdXJ2ZWtwcHdldWFxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY3NjkwMDYsImV4cCI6MjA4MjM0NTAwNn0.iNQi8kiOTfuvfidrldlj2WlTpXVa8roau3tCCeLWqHs';

  static const String roomTable = 'rooms';
  static const String playersTable = 'room_players';

  // Realtime channel names
  static String roomChannel(String roomId) => 'room:$roomId';
}
