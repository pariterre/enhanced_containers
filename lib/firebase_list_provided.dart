import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

import 'exceptions.dart';
import 'item_serializable.dart';
import 'list_provided.dart';
import 'database_list_provided.dart';

/// A [ListProvided] that automagically saves all of its into Firebase's Realtime Database, and notifies of changes made in real time.
///
/// Written by: @Guibi1
abstract class FirebaseListProvided<T> extends DatabaseListProvided<T> {
  /// Creates a [FirebaseListProvided] with the specified data path and ids path.
  FirebaseListProvided({
    String? pathToAvailableDataIds,
    required this.pathToData,
  })  : _pathToAvailableDataIds = pathToAvailableDataIds ?? "$pathToData-ids",
        super() {
    _listenToDatabase();
  }

  void _listenToDatabase() {
    // Listen to added ids
    _availableDataIdsAddedSubscription =
        _availableIdsRef.onChildAdded.listen((DatabaseEvent event) {
      String id = event.snapshot.key!;
      // Get the new enterprise's data
      _dataRef.child(id).get().then((data) {
        // Add it to the list and notify
        super.add(
            deserializeItem((data.value! as Map)
                .map((key, value) => MapEntry(key.toString(), value))),
            notify: true);
      });

      // Listen to data changes
      _dataSubscriptions[id] =
          _dataRef.child(id).onChildChanged.listen((DatabaseEvent event) {
        // Serialise the current enterprise and update the new value
        var map = (this[id] as ItemSerializable).serialize();
        map[event.snapshot.key!] = event.snapshot.value;

        // Replace the enterprise in the list and notify
        super.replace(deserializeItem(map), notify: true);
      });
    });

    // Listen to removed ids
    _availableDataIdsRemovedSubscription =
        _availableIdsRef.onChildRemoved.listen((DatabaseEvent event) {
      // Stop listening to data changes
      _dataSubscriptions.remove(event.snapshot.key!)?.cancel();
      // Remove the enterprise from the list and notify
      super.remove(event.snapshot.key!, notify: true);
    });
  }

  /// Adds an item to the Realtime Database.
  ///
  /// Note that [notify] has no effect here and should not be used.
  @override
  void add(T item, {bool notify = true}) {
    assert(notify, "Notify has no effect here and should not be used.");

    _dataRef.child((item as ItemSerializable).id).set(item.serialize());
    _availableIdsRef.child(item.id).set(true);
  }

  /// Replaces the current item by [item] in the Realtime Database.
  /// The item to replace is identified by its id.
  ///
  /// Note that [notify] has no effect here and should not be used.
  @override
  void replace(T item, {bool notify = true}) {
    assert(notify, "Notify has no effect here and should not be used.");

    _dataRef.child((item as ItemSerializable).id).set(item.serialize());
  }

  /// You can't not use this function with [FirebaseListProvided] in case the ids of the provided values dont match.
  /// Use the function [replace] intead.
  @override
  operator []=(value, T item) {
    throw const ShouldNotCall(
        "You should not use this operator. Use the function replace instead.");
  }

  /// Removes an item from the Realtime Database.
  ///
  /// Note that [notify] has no effect here and should not be used.
  @override
  void remove(value, {bool notify = true}) {
    assert(notify, "Notify has no effect here and should not be used.");

    _availableIdsRef.child((this[value] as ItemSerializable).id).remove();
    _dataRef.child((this[value] as ItemSerializable).id).remove();
  }

  /// Removes all objects from this list and from the Realtime Database; the length of the list becomes zero.
  /// Setting [confirm] to true is required in order to call this function as a 'security' mesure.
  ///
  /// Note that [notify] has no effect here and should not be used.
  @override
  void clear({bool confirm = false, bool notify = true}) {
    assert(notify, "Notify has no effect here and should not be used.");
    if (!confirm) {
      throw const ShouldNotCall(
          "You almost cleared the entire database ! Set the parameter confirm to true if that was really your intention.");
    }

    for (final item in this) {
      remove(item);
    }
  }

  /// The path to the list of available ids inside the database.
  String _pathToAvailableDataIds;
  String get pathToAvailableDataIds => _pathToAvailableDataIds;
  set pathToAvailableDataIds(String newPath) {
    _availableDataIdsAddedSubscription.cancel();
    _availableDataIdsRemovedSubscription.cancel();
    _dataSubscriptions.forEach((id, sub) => sub.cancel());

    super.clear();

    _pathToAvailableDataIds = newPath;
    _listenToDatabase();
  }

  /// The path to the stored data inside the database.
  final String pathToData;

  late StreamSubscription<DatabaseEvent> _availableDataIdsAddedSubscription;
  late StreamSubscription<DatabaseEvent> _availableDataIdsRemovedSubscription;

  final Map<String, StreamSubscription<DatabaseEvent>> _dataSubscriptions = {};

  DatabaseReference get _availableIdsRef =>
      FirebaseDatabase.instance.ref(_pathToAvailableDataIds);
  DatabaseReference get _dataRef => FirebaseDatabase.instance.ref(pathToData);
}
