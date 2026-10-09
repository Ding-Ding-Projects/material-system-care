import { readFile, mkdir, writeFile } from 'node:fs/promises';
const root = new URL('../../', import.meta.url);
const ledgerPath = new URL('contracts/capabilities.json', root);
const publicRoot = new URL('../public/', import.meta.url);
await mkdir(publicRoot, { recursive: true });
let ledger;
try { ledger = JSON.parse(await readFile(ledgerPath, 'utf8')); }
catch { throw new Error('The reviewed capability ledger must exist before the website builds.'); }
await writeFile(new URL('coverage.json', publicRoot), JSON.stringify(ledger));
