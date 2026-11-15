import 'package:sva_core/sva_core.dart';

/// The details Sva records, as data. To add one, add a definition here (and
/// its display text to the translations); the log form, the Explorer and
/// storage pick it up without other code changes. Never rename a key or a
/// value key once released: logged values point at them.
///
/// Keys in [typedAttributeColumns] are stored in typed columns for fast
/// filtering; every other key is stored in the attribute tables. Only
/// routes and ascents have attribute tables so far, so a new area, pitch or
/// session detail needs a typed column (and a migration) for now.
const attributeSeed = <AttributeDef>[
  // Area
  AttributeDef(
    key: 'rock_type',
    level: AttributeLevel.area,
    valueType: AttributeValueType.single,
    valueKeys: [
      'rock.granite',
      'rock.gneiss',
      'rock.limestone',
      'rock.sandstone',
      'rock.basalt',
      'rock.conglomerate',
      'rock.quartzite',
      'rock.schist',
      'rock.dolerite',
    ],
    sort: 10,
  ),
  AttributeDef(
    key: 'aspect',
    level: AttributeLevel.area,
    valueType: AttributeValueType.single,
    valueKeys: ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'],
    sort: 20,
  ),
  // Route
  AttributeDef(
    key: 'discipline',
    level: AttributeLevel.route,
    valueType: AttributeValueType.single,
    valueKeys: [
      'sport',
      'trad',
      'boulder',
      'alpine',
      'ice',
      'mixed',
      'aid',
      'dws',
    ],
    sort: 10,
  ),
  AttributeDef(
    key: 'angle',
    level: AttributeLevel.route,
    valueType: AttributeValueType.single,
    valueKeys: ['angle.slab', 'angle.vertical', 'angle.overhang', 'angle.roof'],
    sort: 20,
  ),
  AttributeDef(
    key: 'feature',
    level: AttributeLevel.route,
    valueType: AttributeValueType.multi,
    valueKeys: [
      'feature.face',
      'feature.finger_crack',
      'feature.hand_crack',
      'feature.offwidth',
      'feature.chimney',
      'feature.corner',
      'feature.arete',
      'feature.tufa',
      'feature.ice_pillar',
      'feature.ice_curtain',
      'feature.mixed_dry_tool',
    ],
    sort: 30,
  ),
  AttributeDef(
    key: 'hold',
    level: AttributeLevel.route,
    valueType: AttributeValueType.multi,
    valueKeys: [
      'hold.crimp',
      'hold.pocket',
      'hold.pinch',
      'hold.sloper',
      'hold.jug',
      'hold.undercling',
      'hold.sidepull',
    ],
    sort: 40,
  ),
  AttributeDef(
    key: 'protection',
    level: AttributeLevel.route,
    valueType: AttributeValueType.single,
    valueKeys: [
      'protection.bolted',
      'protection.trad',
      'protection.mixed',
      'protection.runout',
      'protection.none',
      'protection.pads',
      'protection.ice_screws',
    ],
    sort: 50,
  ),
  AttributeDef(
    key: 'descent',
    level: AttributeLevel.route,
    valueType: AttributeValueType.single,
    valueKeys: [
      'descent.lower_off',
      'descent.rappel',
      'descent.walk_off',
      'descent.downclimb',
      'descent.swim',
    ],
    sort: 60,
  ),
  AttributeDef(
    key: 'rope_length_m',
    level: AttributeLevel.route,
    valueType: AttributeValueType.number,
    sort: 70,
  ),
  // Ascent
  AttributeDef(
    key: 'feel',
    level: AttributeLevel.ascent,
    valueType: AttributeValueType.single,
    valueKeys: [
      'feel.very_soft',
      'feel.soft',
      'feel.fair',
      'feel.hard',
      'feel.very_hard',
    ],
    sort: 10,
  ),
  AttributeDef(
    key: 'tag',
    level: AttributeLevel.ascent,
    valueType: AttributeValueType.multi,
    valueKeys: [
      'tag.pumpy',
      'tag.techy',
      'tag.powerful',
      'tag.scary',
      'tag.sustained',
      'tag.reachy',
      'tag.polished',
      'tag.great_rock',
      'tag.heady',
      'tag.balancy',
    ],
    sort: 20,
  ),
  // A gym climb's main holds and movement, for the style profile (M3-8).
  // A route's holds are its own 'hold'; these are how you climbed it.
  AttributeDef(
    key: 'climb_hold',
    level: AttributeLevel.ascent,
    valueType: AttributeValueType.multi,
    valueKeys: [
      'hold.crimp',
      'hold.sloper',
      'hold.pinch',
      'hold.jug',
      'hold.pocket',
      'hold.volume',
    ],
    sort: 30,
  ),
  AttributeDef(
    key: 'movement',
    level: AttributeLevel.ascent,
    valueType: AttributeValueType.multi,
    valueKeys: [
      'movement.powerful',
      'movement.technical',
      'movement.balance',
      'movement.coordination',
      'movement.dyno',
      'movement.compression',
    ],
    sort: 40,
  ),
  // Session
  AttributeDef(
    key: 'conditions',
    level: AttributeLevel.session,
    valueType: AttributeValueType.single,
    valueKeys: [
      'condition.perfect',
      'condition.dry',
      'condition.humid',
      'condition.damp',
      'condition.wet',
      'condition.icy',
      'condition.windy',
      'condition.cold',
      'condition.hot',
    ],
    sort: 10,
  ),
];

/// Attribute keys stored in a typed column instead of the attribute tables,
/// by level: attribute key → column name.
const typedAttributeColumns = <AttributeLevel, Map<String, String>>{
  AttributeLevel.area: {'rock_type': 'rock_type', 'aspect': 'aspect'},
  AttributeLevel.route: {
    'discipline': 'discipline',
    'angle': 'angle',
    'protection': 'protection',
    'descent': 'descent',
    'rope_length_m': 'rope_length_m',
  },
  AttributeLevel.ascent: {'feel': 'feel'},
  AttributeLevel.session: {'conditions': 'conditions'},
};
