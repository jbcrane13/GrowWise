#!/usr/bin/env node
/**
 * Test script for metrics converter
 * Validates that all improvements are working correctly
 */

const MetricsConverter = require('./metrics-converter');
const fs = require('fs').promises;
const path = require('path');
const assert = require('assert');

async function runTests() {
    console.log('🧪 Running metrics converter tests...\n');
    
    const converter = new MetricsConverter({ precision: 2 });
    const testDir = '.claude-flow/metrics/test';
    
    // Create test directory
    await fs.mkdir(testDir, { recursive: true });
    
    // Test 1: Precision rounding
    console.log('Test 1: Float precision normalization');
    const testData1 = [{
        cpuUsage: 45.123456789,
        memoryUsage: 67.987654321,
        timestamp: Date.now()
    }];
    
    const result1 = converter.extractStaticFields(testData1);
    assert.strictEqual(result1.samples[0].cpuUsage, 45.12, 'CPU usage should be rounded to 2 decimals');
    assert.strictEqual(result1.samples[0].memoryUsage, 67.99, 'Memory usage should be rounded to 2 decimals');
    console.log('✅ Precision rounding works\n');
    
    // Test 2: Unique key generation
    console.log('Test 2: Unique key generation');
    const hostId = converter.hostId;
    const timestamp = 1234567890;
    const key1 = converter.generateUniqueKey(hostId, timestamp);
    const key2 = converter.generateUniqueKey(hostId, timestamp);
    assert.strictEqual(key1, key2, 'Same inputs should generate same key');
    
    const key3 = converter.generateUniqueKey(hostId, timestamp + 1);
    assert.notStrictEqual(key1, key3, 'Different timestamps should generate different keys');
    console.log('✅ Unique key generation works\n');
    
    // Test 3: Static field extraction
    console.log('Test 3: Static field extraction');
    const testData3 = [
        { platform: 'darwin', cpuCount: 8, memoryTotal: 16000000, cpuUsage: 10, timestamp: 1 },
        { platform: 'darwin', cpuCount: 8, memoryTotal: 16000000, cpuUsage: 20, timestamp: 2 },
        { platform: 'darwin', cpuCount: 8, memoryTotal: 16000000, cpuUsage: 30, timestamp: 3 }
    ];
    
    const result3 = converter.extractStaticFields(testData3);
    assert(result3.meta.platform === 'darwin', 'Platform should be in meta');
    assert(result3.meta.cpuCount === 8, 'CPU count should be in meta');
    assert(!result3.samples[0].platform, 'Platform should not be in samples');
    assert(!result3.samples[0].cpuCount, 'CPU count should not be in samples');
    console.log('✅ Static field extraction works\n');
    
    // Test 4: Schema versioning and provenance
    console.log('Test 4: Schema versioning and provenance');
    const testFile = path.join(testDir, 'test-input.json');
    const outputFile = path.join(testDir, 'test-output.json');
    
    await fs.writeFile(testFile, JSON.stringify(testData3));
    const result4 = await converter.convertFile(testFile, outputFile);
    
    assert(result4.meta.schemaVersion, 'Schema version should be present');
    assert(result4.meta.hostId, 'Host ID should be present');
    assert(result4.provenance, 'Provenance should be present');
    assert(result4.retentionPolicy, 'Retention policy should be present');
    console.log('✅ Schema versioning and provenance work\n');
    
    // Test 5: NDJSON output
    console.log('Test 5: NDJSON format output');
    const ndjsonFile = path.join(testDir, 'test-output.ndjson');
    await converter.convertFile(testFile, ndjsonFile);
    
    const ndjsonContent = await fs.readFile(ndjsonFile, 'utf8');
    const lines = ndjsonContent.split('\n').filter(l => l.trim());
    assert(lines.length > 1, 'NDJSON should have multiple lines');
    
    const firstLine = JSON.parse(lines[0]);
    assert(firstLine._meta, 'First line should contain metadata');
    console.log('✅ NDJSON output works\n');
    
    // Clean up test files
    await fs.rm(testDir, { recursive: true });
    
    console.log('🎉 All tests passed!');
}

runTests().catch(error => {
    console.error('❌ Test failed:', error);
    process.exit(1);
});