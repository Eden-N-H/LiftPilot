# LiftPilot

LiftPilot addresses the difficulty that many gym-goers and weightlifters face when trying to achieve a specific strength goal, for example, the popular target of a 225 lb (102 kg) bench press. It provides self-coached lifters with dynamic, goal-oriented guidance: recommended weights for each session, a timeline towards their target, and adjustments when progress deviates.

> 40005 Advanced iOS Development · Assessment Task 3 · Eden Hallett (24833648)

**AI acknowledgement:** I acknowledge that AI was used to generate code in this project and to help create a tailored README.

---

## Domain context

While many lifters have a clear long-term target, achieving this goal requires a structured approach to progressive overload. Without a clear plan, progression becomes inconsistent, lifters plateau, and they struggle to discern what they should do in their next training session to move closer to their goal. Many novice and intermediate lifters select weights based on how they feel on the day rather than according to a structured progression plan.

Research demonstrates that lifters often fail to select training intensities that are optimal for developing strength. A meta-analysis of 18 studies found that participants, on average, selected loads equivalent to 53% of their 1RM, with training experience having little effect on this (Steele et al., 2022). A 12-week study also showed that lifters supervised by a personal trainer increased their training loads at a greater rate and achieved greater strength gains than those who were unsupervised (Mazzetti et al., 2000).

Most existing tools either record the user's lifts or impose a pre-built program, with few allowing the user to define their own target and showing whether they are on track to reach it. Rather than simply recording physical activity, LiftPilot provides a clear next step toward the lifter's goal. It does not seek to replace a coach's guidance regarding technique, but rather to focus specifically on load progression.

**Primary stakeholder:** the self-coached gym-goer/weightlifter, approximately 6 months to 3 years into weight training, who has a specific numeric goal on a barbell lift (such as the bench press, squat or deadlift) but does not necessarily have the knowledge or a structured training plan conducive to reaching it.

### Training rules

| Rule | How LiftPilot applies it |
|---|---|
| Goal lifts | Bench press, back squat, deadlift and overhead press |
| Estimated max | Epley formula: weight × (1 + reps ÷ 30). A single counts as itself; sets over 10 reps are not used |
| Rep scheme | 3 working sets of 6–8 reps (double progression) |
| Starting weight | 75% of the estimated max from the lifter's reference set, rounded down to a loadable weight |
| Progression | All sets reach 8 reps → add 2.5 kg (bench, overhead press) or 5 kg (squat, deadlift) and return to 6 reps. All sets reach at least 6 reps → same weight, one more rep |
| Missed session | Any working set under 6 reps → repeat the same weight |
| Deload | Two missed sessions in a row at the same weight → drop to 90% and recalculate the goal timeline |
| Planned timeline | The best case if every session goes to plan, set when the goal is created |
| Forecast | Trend of each session's best estimated max over the last 6 weeks. Needs at least 4 sessions across 14 days; gaining less than 0.25 kg per week counts as stalled |
| Goal reached | Estimated max ≥ target → "ready to test". Logging a set at or above the target marks the goal achieved |

---

## Architecture

LiftPilot follows MVVM with a Use Case layer and semantic domain models.

```
SwiftUI Views
      ↓
ViewModels (one per screen, @MainActor ObservableObject)
      ↓
Use Cases (business rules + typed LocalizedError enums)
      ↓
TrainingLogRepository (protocol)
      ↓
CoreDataTrainingLogRepository → Core Data
```

- Views and ViewModels never access Core Data. The repository is the only type that handles managed objects, and it returns plain domain structs (`Exercise`, `WorkoutSession`, `ExerciseSet`, `LiftGoal`).
- `AppDependencies` creates the repository and use cases once at launch and passes them to each ViewModel.
- Unit tests swap in `MockTrainingLogRepository`, an in-memory implementation of the same protocol.

### Screens

Today · Active Workout · Workout Summary · Lifts · Lift Detail · Set Goal · Settings

### Use cases

| Use case | Business rules enforced |
|---|---|
| `SetLiftGoalUseCase` | Main barbell lifts only; one active goal per lift; reference set of 1–10 reps; target above the current estimated max and no more than double it; 1–4 sessions per week |
| `PrescribeNextSessionUseCase` | Double progression, missed session and deload rules, derived from logged history rather than stored |
| `LogWorkingSetUseCase` | Workout must be in progress; 1–30 reps; barbell weights must be loadable with standard plates on a 20 kg bar |
| `FinishWorkoutSessionUseCase` | At least one set logged and can't be finished twice; marks goals achieved; recalculates the plan after a deload |
| `ForecastGoalAchievementUseCase` | Minimum data, stall threshold and comparison with the planned timeline |
| `StartWorkoutSessionUseCase` | Only one workout can be in progress at a time |

### Core Data schema

- `WorkoutSessionEntity` 1 → many `ExerciseSetEntity`
- `ExerciseEntity` 1 → many `ExerciseSetEntity`
- `ExerciseEntity` 1 → many `LiftGoalEntity`

Key domain query (every set of one lift from finished workouts since a date, used for prescriptions and forecasts):

```
exercise.id == %@ AND session.finishedAt != nil AND session.startedAt >= %@
```

---

## Extensions

**App Group identifier:** `group.com.eden.LiftPilot`

### WidgetKit widget (`LiftPilotWidget`)

A lifter will usually lock their phone while resting between sets, with the device often sitting on the floor, a bench or nearby equipment. Requiring the user to unlock their phone and navigate through the application every time they would like to check their rest time or next set creates friction, particularly when their hands may be sweaty or covered in chalk.

The widget supports two widget families, each serving a distinct moment in the lifter's day:

- **Lock Screen (rectangular):** during a workout, the widget displays the live rest countdown and the lifter's next set, visible without unlocking the phone.
- **Home Screen (small):** before heading to the gym, it displays the next session's prescribed weight for the lifter's goal lift and their progress towards their target.

This allows the extension to integrate into the lifter's workflow rather than simply providing a different way to access information that is already accessible in the application.

The widget does not access Core Data directly. Instead, after each relevant change (logging or deleting a set, skipping rest, finishing a workout or saving a goal), the main application writes a small `TrainingSnapshot` to the App Group shared container and calls `WidgetCenter.shared.reloadAllTimelines()`. This provides the extension with the relevant information while maintaining clear architectural boundaries.

### Notification Content Extension (`RestNotificationContent`)

During a rest period, the lifter must also prepare the equipment for their next set. Working out which plates are required for a specific weight, such as 92.5 kg, can be inconvenient during a workout.

The Notification Content Extension addresses this by presenting the most relevant information within the notification itself. When the rest timer ends, a `REST_COMPLETE` notification is delivered, and its custom view displays the target weight for the next set, the plate breakdown for each side of the bar, the same set from the last session and progress towards the goal. This allows the lifter to load the bar without opening the application.

Because the extension runs as a separate process in its own sandbox, it cannot read the Core Data store. The main application calculates the required information when the set is logged and sends it as part of the notification payload.

---

## Database choice: Core Data

The data is personal to one lifter, the purpose of the app is not to share data, and logging must work offline, as gym reception can be unreliable. Core Data is private, local and fast, aligning well with the application's use case.

The domain data is naturally relational: a workout session contains many sets, each set records one exercise, and a lift goal belongs to an exercise. LiftPilot's queries depend on these relationships, for instance, retrieving the best set for an exercise from recent sessions to calculate the lifter's estimated max trend.

CloudKit would add an iCloud account requirement and sync complexity that the user is unlikely to benefit from, as they typically train with one phone rather than switching between multiple iOS devices. If multi-device support were needed in the future, Core Data can be extended to sync through `NSPersistentCloudKitContainer` without changing the schema.

---

## Setup

**Requirements:** Xcode 26 and an iOS 17+ simulator (developed and tested on the iPhone 17 Pro simulator, iOS 26.4).

1. Clone the repository and open `LiftPilot.xcodeproj`.
2. Under **Signing & Capabilities**, select your team for the **LiftPilot**, **LiftPilotWidgetExtension** and **RestNotificationContent** targets. A free personal team works in the simulator.
3. If you change the App Group, update it in the app and widget targets **and** in `Shared/AppGroup.swift`.
4. Select the **LiftPilot** scheme and an iPhone simulator, then run (⌘R). Allow notifications when asked.
5. To see forecasts, charts and the widget straight away, go to **Settings → Load Sample Training History**. This adds six weeks of bench press workouts and a 102.5 kg goal.
6. Run the unit tests with ⌘U (32 tests, using the mock repository rather than Core Data).

**Trying the extensions**

- **Widget:** add the LiftPilot widget to the Home Screen (small) and the Lock Screen (rectangular), then start a workout and tap **Done** on a set to see the rest countdown on the Lock Screen.
- **Notification:** set rest to 1 minute in Settings, log a set, go to the Home Screen and long-press the "Rest over" notification when it arrives.

---

## Project structure

```
LiftPilot/
├── App/            App entry, root tabs, dependencies, preferences, sample data
├── Domain/         Models and domain services (estimator, plate calculator, planner)
├── Data/           Core Data model, persistence, repository protocol + implementation
├── UseCases/       Business operations with typed errors
├── ViewModels/
├── Views/
└── Platform/       Rest notifications and widget snapshot publisher
LiftPilotWidget/            WidgetKit extension
RestNotificationContent/    Notification Content Extension
Shared/                     Snapshot, notification payload and App Group (shared by all three targets)
LiftPilotTests/             Use case and rule tests with MockTrainingLogRepository
```

## Version control

Each major layer and extension was built on its own feature branch and merged into `main` with a merge commit:
`feature/domain-model`, `feature/core-data`, `feature/use-cases`, `feature/screens`, `feature/widget` and `feature/rest-notification`. Commit messages follow Conventional Commits (`feat:`, `fix:`, `test:`, `docs:`).

## Known limitations

- Weights are in kilograms only.
- The notification payload is a snapshot taken when the rest timer starts, so if the lifter changes their workout during the rest period, the notification may show outdated information.
- The rest countdown is shown in a widget rather than a Live Activity, as Live Activities were outside this assessment's extension list.

---

## Attribution

- Estimated one-rep max uses the Epley formula (Epley, 1985).
- Built with Apple frameworks only (SwiftUI, Core Data, WidgetKit, UserNotifications and Swift Charts), with reference to Apple's developer documentation. No third-party packages are used.
- **AI assistance:** I used Claude (Anthropic) to discuss design options and to generate code for each layer of the application, which I reviewed, built and tested before merging. I made the core design decisions myself. AI use is described in the Reflective Report in the Required Document.

### References

- Mazzetti, S. A., et al. (2000). The influence of direct supervision of resistance training on strength performance. *Medicine & Science in Sports & Exercise, 32*(6), 1175–1184.
- Steele, J., et al. (2022). Are trainees lifting heavy enough? Self-selected loads in resistance exercise: A scoping review and exploratory meta-analysis. *Sports Medicine, 52*(12), 2909–2923.
