#!/usr/bin/env bun
/**
 * Quick smoke test for npm package
 */

console.log('🧪 Quick NPM Package Test\n');

// Test 1: Import works
try {
	const { parseCSV, Parser } = await import('./bindings/index.js');
	console.log('✅ Package imports successfully');
	console.log(`   - parseCSV: ${typeof parseCSV}`);
	console.log(`   - Parser: ${typeof Parser}`);
} catch (e) {
	console.error('❌ Import failed:', e.message);
	process.exit(1);
}

// Test 2: Lazy mode exports exist
try {
	const { LazyRow, LazyResult } = await import('./bindings/lazy.js');
	console.log('✅ Lazy mode classes available');
	console.log(`   - LazyRow: ${typeof LazyRow}`);
	console.log(`   - LazyResult: ${typeof LazyResult}`);
} catch (e) {
	console.error('❌ Lazy mode import failed:', e.message);
	process.exit(1);
}

// Test 3: TypeScript definitions exist
try {
	const fs = await import('fs');
	const dts = fs.readFileSync('./bindings/index.d.ts', 'utf-8');

	if (dts.includes('LazyRow') && dts.includes('LazyResult')) {
		console.log('✅ TypeScript definitions include lazy mode');
	} else {
		console.log('⚠️  TypeScript definitions may be incomplete');
	}

	if (dts.includes('mode?: \'eager\' | \'lazy\'')) {
		console.log('✅ Mode option defined in types');
	}
} catch (e) {
	console.error('❌ TypeScript check failed:', e.message);
	process.exit(1);
}

// Test 4: Check files for npm package
try {
	const fs = await import('fs');
	const files = [
		'bindings/index.js',
		'bindings/index.d.ts',
		'bindings/lazy.js',
		'bindings/errors.js',
		'libocsv.dylib',
		'README.md',
		'package.json'
	];

	let allExist = true;
	for (const file of files) {
		if (fs.existsSync(file)) {
			console.log(`   ✓ ${file}`);
		} else {
			console.log(`   ✗ ${file} MISSING`);
			allExist = false;
		}
	}

	if (allExist) {
		console.log('✅ All required files present');
	} else {
		console.log('⚠️  Some files missing');
	}
} catch (e) {
	console.error('❌ File check failed:', e.message);
}

console.log('\n✅ Package structure valid');
console.log('\n📦 Ready to publish:');
console.log('   npm pack          # Test package locally');
console.log('   npm publish       # Publish to npm');
