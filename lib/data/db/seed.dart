import 'tables.dart';

/// Built-in exercise library. Ids are stable so that the same exercise is
/// shared across devices when cloud sync is enabled.
const List<(String id, String name, MuscleGroup group, Equipment equipment)> defaultExercises = [
  ('ex-bench-press', 'Bench Press', MuscleGroup.chest, Equipment.barbell),
  ('ex-incline-db-press', 'Incline Dumbbell Press', MuscleGroup.chest, Equipment.dumbbell),
  ('ex-chest-fly', 'Cable Fly', MuscleGroup.chest, Equipment.cable),
  ('ex-dips', 'Dips', MuscleGroup.chest, Equipment.bodyweight),
  ('ex-push-up', 'Push-up', MuscleGroup.chest, Equipment.bodyweight),
  ('ex-deadlift', 'Deadlift', MuscleGroup.back, Equipment.barbell),
  ('ex-pull-up', 'Pull-up', MuscleGroup.back, Equipment.bodyweight),
  ('ex-barbell-row', 'Barbell Row', MuscleGroup.back, Equipment.barbell),
  ('ex-lat-pulldown', 'Lat Pulldown', MuscleGroup.back, Equipment.cable),
  ('ex-seated-row', 'Seated Cable Row', MuscleGroup.back, Equipment.cable),
  ('ex-ohp', 'Overhead Press', MuscleGroup.shoulders, Equipment.barbell),
  ('ex-db-shoulder-press', 'Dumbbell Shoulder Press', MuscleGroup.shoulders, Equipment.dumbbell),
  ('ex-lateral-raise', 'Lateral Raise', MuscleGroup.shoulders, Equipment.dumbbell),
  ('ex-face-pull', 'Face Pull', MuscleGroup.shoulders, Equipment.cable),
  ('ex-barbell-curl', 'Barbell Curl', MuscleGroup.biceps, Equipment.barbell),
  ('ex-hammer-curl', 'Hammer Curl', MuscleGroup.biceps, Equipment.dumbbell),
  ('ex-triceps-pushdown', 'Triceps Pushdown', MuscleGroup.triceps, Equipment.cable),
  ('ex-skull-crusher', 'Skull Crusher', MuscleGroup.triceps, Equipment.barbell),
  ('ex-squat', 'Back Squat', MuscleGroup.legs, Equipment.barbell),
  ('ex-front-squat', 'Front Squat', MuscleGroup.legs, Equipment.barbell),
  ('ex-leg-press', 'Leg Press', MuscleGroup.legs, Equipment.machine),
  ('ex-rdl', 'Romanian Deadlift', MuscleGroup.legs, Equipment.barbell),
  ('ex-leg-curl', 'Leg Curl', MuscleGroup.legs, Equipment.machine),
  ('ex-leg-extension', 'Leg Extension', MuscleGroup.legs, Equipment.machine),
  ('ex-calf-raise', 'Calf Raise', MuscleGroup.legs, Equipment.machine),
  ('ex-hip-thrust', 'Hip Thrust', MuscleGroup.glutes, Equipment.barbell),
  ('ex-bulgarian-split-squat', 'Bulgarian Split Squat', MuscleGroup.glutes, Equipment.dumbbell),
  ('ex-plank', 'Plank', MuscleGroup.core, Equipment.bodyweight),
  ('ex-hanging-leg-raise', 'Hanging Leg Raise', MuscleGroup.core, Equipment.bodyweight),
  ('ex-cable-crunch', 'Cable Crunch', MuscleGroup.core, Equipment.cable),
  ('ex-kb-swing', 'Kettlebell Swing', MuscleGroup.fullBody, Equipment.kettlebell),
  ('ex-power-clean', 'Power Clean', MuscleGroup.fullBody, Equipment.barbell),
];

/// Starter program created on first launch.
const starterProgram = (
  id: 'prog-starter-ppl',
  name: 'Push / Pull / Legs',
  description: 'Classic 3-day split. Run it twice a week for a 6-day routine.',
  days: [
    (
      id: 'day-starter-push',
      name: 'Push',
      exercises: [
        ('ex-bench-press', 4, 6, 180),
        ('ex-ohp', 3, 8, 150),
        ('ex-incline-db-press', 3, 10, 120),
        ('ex-lateral-raise', 3, 15, 60),
        ('ex-triceps-pushdown', 3, 12, 60),
      ],
    ),
    (
      id: 'day-starter-pull',
      name: 'Pull',
      exercises: [
        ('ex-deadlift', 3, 5, 180),
        ('ex-pull-up', 4, 8, 120),
        ('ex-barbell-row', 3, 8, 120),
        ('ex-face-pull', 3, 15, 60),
        ('ex-barbell-curl', 3, 10, 60),
      ],
    ),
    (
      id: 'day-starter-legs',
      name: 'Legs',
      exercises: [
        ('ex-squat', 4, 6, 180),
        ('ex-rdl', 3, 8, 150),
        ('ex-leg-press', 3, 12, 120),
        ('ex-leg-curl', 3, 12, 60),
        ('ex-calf-raise', 4, 15, 60),
      ],
    ),
  ],
);
