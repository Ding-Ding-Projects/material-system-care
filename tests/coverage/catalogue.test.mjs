import { strict as assert } from 'node:assert';
import { readJson, invariant, exactSet, localFile, references, receipt } from './validation.mjs';
const expected = readJson('tests/coverage/expected-capabilities.json');
export function validateCatalogue(data, release = false) {
  invariant(data.schemaVersion === 1 && data.inventoryVersion === expected.inventoryVersion, 'Wrong catalogue version');
  invariant(data.target === 'Windows 11 x64 only', 'Wrong platform scope');
  const rows = data.capabilities;
  invariant(Array.isArray(rows), 'Missing capabilities');
  exactSet(rows.map(x => x.id), Object.values(expected.families).flat(), 'capability inventory');
  exactSet([...new Set(rows.map(x => x.family))], Object.keys(expected.families), 'families');
  for (const [family, ids] of Object.entries(expected.families)) exactSet(rows.filter(x => x.family === family).map(x => x.id), ids, family);
  for (const row of rows) {
    for (const key of ['referenceProduct','referenceCapability','officialSource','sourceSection','scope','equivalent','platform','safetyBoundary','statusReason','intendedPage','documentation']) invariant(typeof row[key] === 'string' && row[key].trim().length > 0, `Missing ${row.id}.${key}`);
    for (const key of ['referenceCapability','officialSource','scope']) invariant(row[key] === expected.definitions[row.id][key], `Changed fixed definition ${row.id}.${key}`);
    const source = new URL(row.officialSource);
    invariant(source.protocol === 'https:' && ['www.iobit.com','www.macbooster.net'].includes(source.hostname), 'Non-official source');
    invariant(row.platform === 'Windows 11 x64', 'Unsupported target');
    invariant(Array.isArray(row.needs) && row.needs.length > 0, 'Missing platform requirements');
    for (const key of ['implementation','tests','evidence']) invariant(Array.isArray(row[key]), `Missing proof list ${key}`);
    localFile(row.documentation);
    invariant(['unimplemented','unavailable','excluded','verified'].includes(row.status), 'Invalid capability status');
    if (row.status === 'excluded') invariant(row.scope === 'outside-release-boundary', 'Unexplained exclusion');
    if (row.status === 'unavailable') invariant(row.scope === 'engine-unavailable', 'Unexplained unavailable engine');
    if (row.status === 'verified') {
      for (const key of ['implementation','tests','evidence']) references(row[key], `${row.id}.${key}`);
      invariant(row.implementation.every(x => /^(engine|desktop|native|website)\//.test(x)), 'Documentation is not implementation');
      invariant(row.tests.every(x => /^tests\//.test(x)), 'Missing focused tests');
      row.evidence.forEach(x => receipt(x));
      invariant(!['outside-release-boundary','engine-unavailable'].includes(row.scope), 'Unsupported capability cannot be verified');
    }
    if (release) invariant(row.status === 'verified' || row.status === 'excluded', `Incomplete capability ${row.id}: ${row.status}`);
  }
  return true;
}
const baseline = readJson('contracts/capabilities.json');
validateCatalogue(baseline);
let mutations = 0;
function rejects(mutate) { const candidate=structuredClone(baseline); mutate(candidate); assert.throws(()=>validateCatalogue(candidate)); mutations++; }
for (const row of baseline.capabilities) rejects(x => { x.capabilities=x.capabilities.filter(r=>r.id!==row.id); });
for (const family of Object.keys(expected.families)) rejects(x=>{x.capabilities=x.capabilities.filter(r=>r.family!==family);});
for (const key of ['officialSource','scope','safetyBoundary','intendedPage','documentation','statusReason','implementation','tests','evidence']) rejects(x=>{delete x.capabilities[0][key];});
rejects(x=>{x.capabilities[0].status='verified';});
rejects(x=>{x.capabilities[0].status='complete';});
rejects(x=>{x.capabilities[0].status='excluded';x.capabilities[0].scope='outside-release-boundary';});
rejects(x=>{x.capabilities[0].referenceCapability='Unreviewed replacement';});
rejects(x=>{x.capabilities[0].documentation='../AGENTS.md';});
rejects(x=>{x.capabilities[0].officialSource='https://example.com/unverified';});
rejects(x=>{x.capabilities.push(structuredClone(x.capabilities[0]));});
assert.throws(()=>validateCatalogue(baseline,true));
console.log(`PASS catalogue: ${baseline.capabilities.length} fixed capabilities; ${mutations} negative mutations rejected; release completeness remains unverified.`);
if (process.argv.includes('--release')) validateCatalogue(baseline,true);
