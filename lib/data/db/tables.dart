import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generates a new client-side primary key.
String newId() => _uuid.v4();

/// Columns shared by every table that takes part in cloud sync.
///
/// Rows use client-generated UUIDs so they can be created offline and merged
/// later, `updatedAt` drives last-write-wins conflict resolution, and
/// `deleted` is a tombstone so deletions propagate across devices.
mixin SyncColumns on Table {
  TextColumn get id => text().clientDefault(newId)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now())();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

enum MuscleGroup {
  chest,
  back,
  shoulders,
  biceps,
  triceps,
  legs,
  glutes,
  core,
  fullBody;

  String get label => switch (this) {
    MuscleGroup.fullBody => 'Full body',
    _ => name[0].toUpperCase() + name.substring(1),
  };
}

enum Equipment { barbell, dumbbell, machine, cable, bodyweight, kettlebell, other }

@DataClassName('Exercise')
class Exercises extends Table with SyncColumns {
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get muscleGroup => textEnum<MuscleGroup>()();
  TextColumn get equipment => textEnum<Equipment>()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
}

@DataClassName('Program')
class Programs extends Table with SyncColumns {
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get description => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
}

/// A session template inside a program, e.g. "Push" or "Day A".
@DataClassName('ProgramDay')
class ProgramDays extends Table with SyncColumns {
  TextColumn get programId => text().references(Programs, #id)();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  IntColumn get position => integer()();
}

@DataClassName('ProgramExercise')
class ProgramExercises extends Table with SyncColumns {
  TextColumn get dayId => text().references(ProgramDays, #id)();
  TextColumn get exerciseId => text().references(Exercises, #id)();
  IntColumn get position => integer()();
  IntColumn get targetSets => integer().withDefault(const Constant(3))();
  IntColumn get targetReps => integer().withDefault(const Constant(8))();
  IntColumn get restSeconds => integer().withDefault(const Constant(120))();
}

/// A performed training session.
@DataClassName('Workout')
class Workouts extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get programDayId => text().nullable().references(ProgramDays, #id)();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
}

/// An exercise slot inside a workout. Exists before any set is logged so the
/// planned exercises of a program day show up immediately.
@DataClassName('WorkoutExercise')
class WorkoutExercises extends Table with SyncColumns {
  TextColumn get workoutId => text().references(Workouts, #id)();
  TextColumn get exerciseId => text().references(Exercises, #id)();
  IntColumn get position => integer()();
  IntColumn get targetSets => integer().withDefault(const Constant(3))();
  IntColumn get targetReps => integer().withDefault(const Constant(8))();
  IntColumn get restSeconds => integer().withDefault(const Constant(120))();
}

@DataClassName('WorkoutSet')
class WorkoutSets extends Table with SyncColumns {
  TextColumn get workoutExerciseId => text().references(WorkoutExercises, #id)();

  /// Denormalised from the slot so progression queries stay simple.
  TextColumn get workoutId => text().references(Workouts, #id)();
  TextColumn get exerciseId => text().references(Exercises, #id)();

  /// Order of the set within its exercise slot.
  IntColumn get setIndex => integer()();
  RealColumn get weight => real()();
  IntColumn get reps => integer()();
  RealColumn get rpe => real().nullable()();
  DateTimeColumn get completedAt => dateTime()();
}

/// Local key/value preferences. Not synced.
@DataClassName('Setting')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
