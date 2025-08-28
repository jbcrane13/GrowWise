#!/usr/bin/env node
/**
 * Metrics Converter - Normalizes and optimizes metrics data
 * Addresses Comments 2-8: Schema versioning, unique keys, normalized precision,
 * static field extraction, and proper structure
 */

const fs = require('fs').promises;
const crypto = require('crypto');
const path = require('path');

const SCHEMA_VERSION = '2.0.0';
const DEFAULT_PRECISION = 3; // Decimal places for floats

class MetricsConverter {
    constructor(options = {}) {
        this.precision = options.precision || DEFAULT_PRECISION;
        this.hostId = options.hostId || this.generateHostId();
        this.agentVersion = options.agentVersion || process.env.AGENT_VERSION || '1.0.0';
        this.hostname = options.hostname || require('os').hostname();
    }

    generateHostId() {
        // Generate deterministic host ID based on machine characteristics
        const os = require('os');
        const data = `${os.hostname()}-${os.platform()}-${os.arch()}-${os.cpus().length}`;
        return crypto.createHash('sha256').update(data).digest('hex').substring(0, 16);
    }

    generateUniqueKey(hostId, timestamp) {
        // Create composite key for upsert operations (Comment 2)
        return crypto.createHash('sha256')
            .update(`${hostId}-${timestamp}`)
            .digest('hex');
    }

    roundPrecision(value) {
        // Normalize floating-point precision (Comment 4)
        if (typeof value !== 'number') return value;
        return Math.round(value * Math.pow(10, this.precision)) / Math.pow(10, this.precision);
    }

    extractStaticFields(samples) {
        // Extract static fields to reduce redundancy (Comment 6)
        if (!samples || samples.length === 0) return { meta: {}, samples: [] };

        const firstSample = samples[0];
        const meta = {
            schemaVersion: SCHEMA_VERSION,
            hostId: this.hostId,
            hostname: this.hostname,
            agentVersion: this.agentVersion,
            platform: firstSample.platform || process.platform,
            cpuCount: firstSample.cpuCount || require('os').cpus().length,
            memoryTotal: firstSample.memoryTotal || require('os').totalmem(),
            createdAt: new Date().toISOString()
        };

        // Fields that are static and should be moved to meta
        const staticFields = ['platform', 'cpuCount', 'memoryTotal', 'hostname', 'hostId'];

        const processedSamples = samples.map(sample => {
            const processed = { ...sample };
            
            // Add unique key for each sample
            processed.uniqueKey = this.generateUniqueKey(
                this.hostId, 
                sample.timestamp || Date.now()
            );

            // Round all numeric values
            Object.keys(processed).forEach(key => {
                if (typeof processed[key] === 'number') {
                    processed[key] = this.roundPrecision(processed[key]);
                }
            });

            // Remove static fields from individual samples
            staticFields.forEach(field => delete processed[field]);

            return processed;
        });

        return { meta, samples: processedSamples };
    }

    async convertFile(inputPath, outputPath) {
        try {
            const content = await fs.readFile(inputPath, 'utf8');
            let data = JSON.parse(content);

            // Handle array or object input
            const samples = Array.isArray(data) ? data : [data];
            
            // Convert to optimized structure
            const converted = this.extractStaticFields(samples);

            // Add retention policy information (Comment 3)
            converted.retentionPolicy = {
                raw: '1h',      // 1 hour for raw data
                minute: '7d',   // 7 days for 1-minute aggregates  
                hour: '30d',    // 30 days for hourly aggregates
                day: '90d'      // 90 days for daily aggregates
            };

            // Add provenance information (Comment 5)
            converted.provenance = {
                source: 'claude-flow',
                converterVersion: '1.0.0',
                conversionTimestamp: new Date().toISOString()
            };

            // Write to NDJSON format for better diff handling
            if (outputPath.endsWith('.ndjson')) {
                const lines = converted.samples.map(s => JSON.stringify(s));
                lines.unshift(JSON.stringify({ _meta: converted.meta, _retention: converted.retentionPolicy }));
                await fs.writeFile(outputPath, lines.join('\n'));
            } else {
                await fs.writeFile(outputPath, JSON.stringify(converted, null, 2));
            }

            console.log(`✅ Converted ${inputPath} -> ${outputPath}`);
            return converted;
        } catch (error) {
            console.error(`❌ Error converting ${inputPath}:`, error.message);
            throw error;
        }
    }

    async processDirectory(dir) {
        const files = await fs.readdir(dir);
        const jsonFiles = files.filter(f => f.endsWith('.json') && !f.includes('backup'));

        for (const file of jsonFiles) {
            const inputPath = path.join(dir, file);
            const ndjsonPath = path.join(dir, file.replace('.json', '.ndjson'));
            const backupPath = path.join(dir, file + '.backup');

            // Backup original file
            await fs.copyFile(inputPath, backupPath);
            
            // Convert to NDJSON
            await this.convertFile(inputPath, ndjsonPath);
        }
    }
}

// CLI interface
async function main() {
    const args = process.argv.slice(2);
    
    if (args.length === 0) {
        console.log(`
Usage: node metrics-converter.js [input-file] [output-file]
       node metrics-converter.js --dir [directory]
       
Options:
  --precision [n]     Number of decimal places (default: 3)
  --host-id [id]      Override host ID
  --agent-version [v] Override agent version
        `);
        process.exit(0);
    }

    const converter = new MetricsConverter({
        precision: args.includes('--precision') ? 
            parseInt(args[args.indexOf('--precision') + 1]) : DEFAULT_PRECISION,
        hostId: args.includes('--host-id') ? 
            args[args.indexOf('--host-id') + 1] : undefined,
        agentVersion: args.includes('--agent-version') ? 
            args[args.indexOf('--agent-version') + 1] : undefined
    });

    try {
        if (args[0] === '--dir') {
            await converter.processDirectory(args[1] || '.claude-flow/metrics');
        } else {
            await converter.convertFile(args[0], args[1] || args[0].replace('.json', '.ndjson'));
        }
        console.log('✅ Conversion complete');
    } catch (error) {
        console.error('❌ Conversion failed:', error);
        process.exit(1);
    }
}

if (require.main === module) {
    main();
}

module.exports = MetricsConverter;