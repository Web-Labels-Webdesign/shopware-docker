#!/usr/bin/env node

/**
 * Dynamic Matrix Generator for Shopware Development Images
 * 
 * This script generates build matrices for CI/CD by fetching live data
 * from Shopware releases and PHP compatibility information.
 */

import https from 'https';
import fs from 'fs/promises';

// Configuration
const CONFIG = {
  // Shopware releases API
  shopwareReleasesUrl: 'https://api.github.com/repos/shopware/shopware/releases',
  
  // PHP compatibility matrix (manual override for accuracy)
  phpCompatibility: {
    '6.5': ['8.1', '8.2'],
    '6.6': ['8.2', '8.3'], 
    '6.7': ['8.3', '8.4']
  },
  
  // Supported major versions
  supportedMajorVersions: ['6.5', '6.6', '6.7'],
  
  // Node.js versions for each Shopware version
  nodeVersions: {
    '6.5': '20.18.0',
    '6.6': '20.18.0', 
    '6.7': '22.11.0'
  },
  
  // Exclude patterns
  excludePatterns: [
    /rc/i,           // Release candidates
    /beta/i,         // Beta versions
    /alpha/i,        // Alpha versions
    /dev/i,          // Development versions
  ]
};

/**
 * Fetch data from URL with error handling
 */
async function fetchData(url) {
  return new Promise((resolve, reject) => {
    const options = {
      headers: {
        'User-Agent': 'Shopware-Docker-Builder/1.0'
      }
    };
    
    https.get(url, options, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (error) {
          reject(new Error(`Failed to parse JSON: ${error.message}`));
        }
      });
    }).on('error', reject);
  });
}

/**
 * Get Shopware releases from GitHub
 */
async function getShopwareReleases() {
  try {
    console.log('📡 Fetching Shopware releases from GitHub...');
    const releases = await fetchData(CONFIG.shopwareReleasesUrl);
    
    return releases
      .filter(release => !release.prerelease && !release.draft)
      .map(release => ({
        version: release.tag_name.replace(/^v/, ''),
        publishedAt: release.published_at,
        name: release.name
      }))
      .filter(release => {
        // Filter out unwanted versions
        return !CONFIG.excludePatterns.some(pattern => 
          pattern.test(release.version)
        );
      });
  } catch (error) {
    console.warn('⚠️ Failed to fetch from GitHub, using fallback versions');
    console.warn(`Error: ${error.message}`);
    
    // Fallback to hardcoded versions
    return [
      { version: '6.5.8.18', publishedAt: '2024-01-01T00:00:00Z' },
      { version: '6.6.10.6', publishedAt: '2024-06-01T00:00:00Z' },
      { version: '6.7.1.0', publishedAt: '2024-12-01T00:00:00Z' }
    ];
  }
}

/**
 * Determine PHP version for a Shopware version
 */
function getPhpVersion(shopwareVersion) {
  const majorMinor = shopwareVersion.substring(0, 3); // e.g., "6.5"
  const compatibleVersions = CONFIG.phpCompatibility[majorMinor];
  
  if (!compatibleVersions) {
    console.warn(`⚠️ Unknown Shopware version: ${shopwareVersion}, defaulting to PHP 8.3`);
    return '8.3';
  }
  
  // Return the latest compatible PHP version
  return compatibleVersions[compatibleVersions.length - 1];
}

/**
 * Determine Node.js version for a Shopware version
 */
function getNodeVersion(shopwareVersion) {
  const majorMinor = shopwareVersion.substring(0, 3);
  return CONFIG.nodeVersions[majorMinor] || '20.18.0';
}

/**
 * Get the latest patch version for each major.minor
 */
function getLatestPatchVersions(releases) {
  const versionMap = new Map();
  
  releases.forEach(release => {
    const version = release.version;
    const majorMinor = version.substring(0, 3);
    
    // Only process supported major versions
    if (!CONFIG.supportedMajorVersions.includes(majorMinor)) {
      return;
    }
    
    // Keep the latest version for each major.minor
    if (!versionMap.has(majorMinor) || 
        compareVersions(version, versionMap.get(majorMinor).version) > 0) {
      versionMap.set(majorMinor, release);
    }
  });
  
  return Array.from(versionMap.values());
}

/**
 * Simple version comparison (assumes semantic versioning)
 */
function compareVersions(a, b) {
  const aParts = a.split('.').map(Number);
  const bParts = b.split('.').map(Number);
  
  for (let i = 0; i < Math.max(aParts.length, bParts.length); i++) {
    const aPart = aParts[i] || 0;
    const bPart = bParts[i] || 0;
    
    if (aPart > bPart) return 1;
    if (aPart < bPart) return -1;
  }
  
  return 0;
}

/**
 * Generate build matrix
 */
function generateMatrix(releases) {
  const matrix = {
    include: []
  };
  
  releases.forEach(release => {
    const shopwareVersion = release.version;
    const phpVersion = getPhpVersion(shopwareVersion);
    const nodeVersion = getNodeVersion(shopwareVersion);
    const majorMinor = shopwareVersion.substring(0, 3);
    
    // Determine if this is the latest version
    const isLatest = shopwareVersion === '6.7.1.0';
    
    // Generate tags
    const tags = [
      `type=raw,value=${shopwareVersion}`,
      `type=raw,value=${majorMinor}`
    ];
    
    if (isLatest) {
      tags.push('type=raw,value=latest');
    }
    
    // Full variant
    matrix.include.push({
      shopware_version: shopwareVersion,
      php_version: phpVersion,
      node_version: nodeVersion,
      variant: 'full',
      context_path: majorMinor,
      dockerfile: 'Dockerfile',
      tags: tags.join('\n'),
      cache_key: `${majorMinor}-full`,
      is_latest: isLatest
    });
    
    // Slim variant
    const slimTags = tags.map(tag => tag.replace('value=', 'value=') + '-slim')
      .concat(isLatest ? ['type=raw,value=latest-slim'] : []);
    
    matrix.include.push({
      shopware_version: shopwareVersion,
      php_version: phpVersion, 
      node_version: nodeVersion,
      variant: 'slim',
      context_path: majorMinor,
      dockerfile: 'Dockerfile.slim',
      tags: slimTags.join('\n'),
      cache_key: `${majorMinor}-slim`,
      is_latest: isLatest
    });
  });
  
  return matrix;
}

/**
 * Generate Docker Bake file matrix
 */
function generateBakeMatrix(releases) {
  const bakeTargets = {};
  
  releases.forEach(release => {
    const shopwareVersion = release.version;
    const phpVersion = getPhpVersion(shopwareVersion);
    const majorMinor = shopwareVersion.substring(0, 3);
    const isLatest = shopwareVersion === '6.7.1.0';
    
    // Full variant target
    const fullTargetName = `shopware-${majorMinor.replace('.', '-')}-full`;
    bakeTargets[fullTargetName] = {
      shopware_version: shopwareVersion,
      php_version: phpVersion,
      variant: 'full',
      context_path: majorMinor,
      is_latest: isLatest
    };
    
    // Slim variant target  
    const slimTargetName = `shopware-${majorMinor.replace('.', '-')}-slim`;
    bakeTargets[slimTargetName] = {
      shopware_version: shopwareVersion,
      php_version: phpVersion,
      variant: 'slim', 
      context_path: majorMinor,
      is_latest: isLatest
    };
  });
  
  return bakeTargets;
}

/**
 * Main execution
 */
async function main() {
  try {
    console.log('🏗️ Generating dynamic build matrix for Shopware Docker images');
    console.log('=' .repeat(60));
    
    // Fetch releases
    const allReleases = await getShopwareReleases();
    console.log(`📦 Found ${allReleases.length} total releases`);
    
    // Get latest patch versions
    const latestReleases = getLatestPatchVersions(allReleases);
    console.log(`✨ Selected ${latestReleases.length} latest patch versions:`);
    
    latestReleases.forEach(release => {
      const phpVersion = getPhpVersion(release.version);
      const nodeVersion = getNodeVersion(release.version);
      console.log(`  • ${release.version} (PHP ${phpVersion}, Node ${nodeVersion})`);
    });
    
    // Generate matrices
    const githubMatrix = generateMatrix(latestReleases);
    const bakeMatrix = generateBakeMatrix(latestReleases);
    
    // Write outputs
    const outputDir = './build-config';
    await fs.mkdir(outputDir, { recursive: true });
    
    // GitHub Actions matrix
    await fs.writeFile(
      `${outputDir}/github-matrix.json`, 
      JSON.stringify(githubMatrix, null, 2)
    );
    
    // Docker Bake matrix  
    await fs.writeFile(
      `${outputDir}/bake-matrix.json`,
      JSON.stringify(bakeMatrix, null, 2)
    );
    
    // Summary for GitHub Actions output
    const summary = {
      total_variants: githubMatrix.include.length,
      shopware_versions: [...new Set(githubMatrix.include.map(item => item.shopware_version))],
      php_versions: [...new Set(githubMatrix.include.map(item => item.php_version))],
      variants: [...new Set(githubMatrix.include.map(item => item.variant))]
    };
    
    await fs.writeFile(
      `${outputDir}/build-summary.json`,
      JSON.stringify(summary, null, 2)
    );
    
    console.log('\n📊 Matrix Generation Complete!');
    console.log(`📁 Files written to: ${outputDir}/`);
    console.log(`🎯 Total build variants: ${githubMatrix.include.length}`);
    console.log(`🐘 PHP versions: ${summary.php_versions.join(', ')}`);
    console.log(`📦 Shopware versions: ${summary.shopware_versions.join(', ')}`);
    
    // Output for GitHub Actions
    if (process.env.GITHUB_OUTPUT) {
      const githubOutput = `matrix=${JSON.stringify(githubMatrix)}`;
      await fs.appendFile(process.env.GITHUB_OUTPUT, githubOutput);
      console.log('✅ GitHub Actions output written');
    }
    
  } catch (error) {
    console.error('❌ Error generating matrix:');
    console.error(error);
    process.exit(1);
  }
}

// Run if called directly
if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}

export { generateMatrix, getShopwareReleases };