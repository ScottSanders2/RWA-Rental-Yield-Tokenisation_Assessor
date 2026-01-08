#!/usr/bin/env node
/**
 * Generate Combined ABI for DiamondYieldBase
 * 
 * This script merges ABIs from all YieldBase Diamond facets into a single combined ABI
 * that the backend can use to interact with the Diamond proxy address.
 * 
 * As documented in DissertationProgress.md Section 4.6 (Iteration 15):
 * "Backend integration requires combined ABI from all facets (YieldBaseFacet + RepaymentFacet + 
 * GovernanceFacet + ... = ~42 functions in single ABI array)"
 */

const fs = require('fs');
const path = require('path');

// Facets to include in combined ABI
const FACETS = [
  'YieldBaseFacet',
  'RepaymentFacet',
  'GovernanceFacet',
  'DefaultManagementFacet',
  'ViewsFacet',
  'KYCFacet',
  'DiamondLoupeFacet',  // For introspection (facets(), facetAddresses())
  'OwnershipFacet'       // For owner()
];

const OUT_DIR = path.join(__dirname, '../out');
const OUTPUT_FILE = path.join(OUT_DIR, 'DiamondYieldBase_ABI.json');

console.log('🔷 Generating Combined ABI for DiamondYieldBase...\n');

let combinedABI = [];
let functionCount = 0;
let eventCount = 0;
let errorCount = 0;

// Track function selectors to detect duplicates
const seenSelectors = new Map();

for (const facetName of FACETS) {
  const abiPath = path.join(OUT_DIR, `${facetName}.sol`, `${facetName}.json`);
  
  if (!fs.existsSync(abiPath)) {
    console.error(`❌ ERROR: ABI file not found: ${abiPath}`);
    console.error(`   Did you run 'forge build' first?`);
    process.exit(1);
  }
  
  console.log(`📄 Reading ${facetName}...`);
  const contractJSON = JSON.parse(fs.readFileSync(abiPath, 'utf8'));
  const abi = contractJSON.abi;
  
  if (!Array.isArray(abi)) {
    console.error(`❌ ERROR: Invalid ABI format in ${abiPath}`);
    process.exit(1);
  }
  
  let facetFunctions = 0;
  let facetEvents = 0;
  let facetErrors = 0;
  
  for (const item of abi) {
    // Track function selectors to detect duplicates
    if (item.type === 'function') {
      const signature = `${item.name}(${item.inputs.map(i => i.type).join(',')})`;
      
      if (seenSelectors.has(signature)) {
        console.log(`   ⚠️  Skipping duplicate function: ${signature} (already in ${seenSelectors.get(signature)})`);
        continue;
      }
      
      seenSelectors.set(signature, facetName);
      facetFunctions++;
    } else if (item.type === 'event') {
      facetEvents++;
    } else if (item.type === 'error') {
      facetErrors++;
    }
    
    combinedABI.push(item);
  }
  
  functionCount += facetFunctions;
  eventCount += facetEvents;
  errorCount += facetErrors;
  
  console.log(`   ✅ Added ${facetFunctions} functions, ${facetEvents} events, ${facetErrors} errors`);
}

// Write combined ABI
fs.writeFileSync(OUTPUT_FILE, JSON.stringify(combinedABI, null, 2), 'utf8');

console.log(`\n✅ Combined ABI generated successfully!`);
console.log(`📁 Output: ${OUTPUT_FILE}`);
console.log(`\n📊 Summary:`);
console.log(`   Total Functions: ${functionCount}`);
console.log(`   Total Events: ${eventCount}`);
console.log(`   Total Errors: ${errorCount}`);
console.log(`   Total ABI Items: ${combinedABI.length}`);
console.log(`\n💡 Backend can now use this combined ABI with the DiamondYieldBase proxy address.`);

