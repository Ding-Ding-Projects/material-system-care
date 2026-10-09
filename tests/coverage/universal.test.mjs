import { strict as assert } from 'node:assert';
import { readJson, invariant, exactSet, localFile, references, receipt } from './validation.mjs';
const expected=readJson('tests/coverage/expected-universal.json');
export function validateUniversal(data,release=false) {
  invariant(data.schemaVersion===1,'Wrong surface inventory version');
  exactSet(data.features.map(x=>x.id),expected.features,'canonical contract inventory');
  exactSet(data.surfaces.map(x=>x.id),expected.surfaces,'surface inventory');
  exactSet(data.requirements.map(x=>`${x.surface}:${x.feature}`),expected.surfaces.flatMap(s=>expected.surfaceFeatures.map(f=>`${s}:${f}`)),'surface requirements');
  exactSet(data.deliveryRequirements.map(x=>x.feature),expected.features.filter(x=>!expected.surfaceFeatures.includes(x)),'delivery requirements');
  for(const feature of data.features)localFile(feature.documentation);
  for(const row of data.requirements) {
    invariant(['unimplemented','verified'].includes(row.status),'Invalid surface status');
    invariant(typeof row.reason==='string'&&row.reason.length>0,'Missing surface explanation');
    localFile(row.documentation);
    for(const key of ['implementation','localizedCopy','persistence','tests','interactions','captures'])invariant(Array.isArray(row[key]),`Missing ${key}`);
    if(row.status==='verified') {
      for(const key of ['implementation','localizedCopy','persistence','tests','interactions','captures'])references(row[key],`${row.surface}.${row.feature}.${key}`);
      invariant(row.implementation.every(x=>/^(desktop|website)\//.test(x)),'Missing surface implementation');
      invariant(row.tests.every(x=>/^tests\//.test(x)),'Missing focused tests');
      row.interactions.forEach(x=>receipt(x,row.surface));row.captures.forEach(x=>receipt(x,row.surface));
    }
    if(release)invariant(row.status==='verified',`Incomplete surface ${row.surface}:${row.feature}`);
  }
  for(const row of data.deliveryRequirements) {
    invariant(['unimplemented','not-applicable','verified'].includes(row.status),'Invalid delivery status');
    invariant(typeof row.reason==='string'&&row.reason.length>0,'Missing delivery explanation');
    for(const key of ['implementation','tests','evidence'])invariant(Array.isArray(row[key]),`Missing delivery ${key}`);
    if(row.status==='not-applicable')invariant(expected.notApplicableDelivery[row.feature]===row.reason,'Unreviewed delivery exemption');
    if(row.status==='verified')for(const key of ['implementation','tests','evidence'])references(row[key],key);
    if(release)invariant(row.status==='verified'||row.status==='not-applicable',`Incomplete delivery ${row.feature}`);
  }
  return true;
}
const baseline=readJson('docs/architecture/surface-completeness.json');validateUniversal(baseline);
let mutations=0;
function rejects(mutate){const x=structuredClone(baseline);mutate(x);assert.throws(()=>validateUniversal(x));mutations++;}
for(const feature of expected.features)rejects(x=>{x.features=x.features.filter(f=>f.id!==feature);});
for(const surface of expected.surfaces)rejects(x=>{x.surfaces=x.surfaces.filter(s=>s.id!==surface);});
for(const feature of expected.surfaceFeatures)rejects(x=>{x.requirements=x.requirements.filter(r=>r.feature!==feature);});
for(const key of ['implementation','documentation','localizedCopy','persistence','tests','interactions','captures'])rejects(x=>{delete x.requirements[0][key];});
rejects(x=>{x.requirements[0].status='verified';});rejects(x=>{x.requirements[0].status='not-applicable';});
rejects(x=>{x.requirements[0].captures=['docs/catalogue/README.md'];x.requirements[0].status='verified';});
rejects(x=>{x.requirements.push(structuredClone(x.requirements[0]));});
rejects(x=>{x.deliveryRequirements[0].status='not-applicable';x.deliveryRequirements[0].reason='Too small';});
assert.throws(()=>validateUniversal(baseline,true));
console.log(`PASS universal: ${expected.features.length} fixed contracts, ${expected.surfaces.length} surfaces, ${baseline.requirements.length} rows; ${mutations} negative mutations rejected; release completeness remains unverified.`);
if(process.argv.includes('--release'))validateUniversal(baseline,true);
