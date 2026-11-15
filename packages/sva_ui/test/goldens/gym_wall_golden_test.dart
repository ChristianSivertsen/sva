import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:sva_ui/sva_ui.dart';

Future<void> main() async {
  Widget framed(ThemeData theme, Widget child) => Theme(
    data: theme,
    child: Material(
      color: theme.scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(SvaSpace.md),
        child: SizedBox(width: 380, child: child),
      ),
    ),
  );

  // A colour gym: holds in the gym's own colours.
  Widget card(ThemeData theme) => framed(
    theme,
    SvaSessionCard(
      place: 'Gnisten',
      when: '12 Nov 2026 · with Kari',
      title: '3 boulders · best Blue',
      picture: SvaGymWall(
        holds: [
          for (final hex in ['#2E9E4F', '#2F6FD1', '#2F6FD1', '#1B1B1B'])
            gymColourFromHex(hex),
        ],
        label: 'Gnisten · 4 climbs',
        semanticLabel: 'Wall at Gnisten with 4 climbs',
        seed: 'session-1',
      ),
      climbs: const [
        SvaCardClimb(
          name: 'Green',
          detail: 'Cave',
          style: 'flash',
          styleLabel: 'Flash',
        ),
        SvaCardClimb(
          name: 'Blue',
          detail: 'Slab',
          style: 'redpoint',
          styleLabel: 'Redpoint',
        ),
      ],
      more: '+2 more climbs',
      openLabel: 'Open session',
    ),
  );

  // A graded gym: each band from pale to deep, then a climb with no grade.
  Widget graded(ThemeData theme) => framed(
    theme,
    SvaGymWall(
      holds: [
        for (final band in [0, 1, 2, 3])
          for (final depth in [0.0, 1.0])
            gymGradeShade(theme.brightness, band, depth),
        null,
      ],
      label: 'Klatreverket · 9 climbs',
      semanticLabel: 'Wall at Klatreverket with 9 climbs',
      seed: 'session-2',
    ),
  );

  await goldenTest(
    'M3-9: an indoor session card leads with its wall, in both themes',
    fileName: 'gym_wall',
    builder: () => GoldenTestGroup(
      columns: 2,
      children: [
        GoldenTestScenario(
          name: 'Midnight sun',
          child: card(SvaTheme.midnight()),
        ),
        GoldenTestScenario(name: 'Daylight', child: card(SvaTheme.daylight())),
        GoldenTestScenario(
          name: 'Grade shades, Midnight sun',
          child: graded(SvaTheme.midnight()),
        ),
        GoldenTestScenario(
          name: 'Grade shades, Daylight',
          child: graded(SvaTheme.daylight()),
        ),
      ],
    ),
  );
}
