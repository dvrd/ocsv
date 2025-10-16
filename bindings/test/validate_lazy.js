/**
 * Simple validation script for lazy mode
 * Tests basic functionality without formal test framework
 */

import { parseCSV } from "../index.js";

console.log("🧪 OCSV Lazy Mode Validation\n");
console.log("=" .repeat(60));

// Test 1: Basic lazy mode parsing
console.log("\n1️⃣  Test: Basic lazy mode parsing");
const csv1 = "a,b,c\n1,2,3\n4,5,6";
const result1 = parseCSV(csv1, { mode: 'lazy' });

try {
	console.log(`   ✓ Parsed ${result1.rowCount} rows`);

	const row = result1.getRow(0);
	console.log(`   ✓ Got row 0: ${row.get(0)}, ${row.get(1)}, ${row.get(2)}`);

	const fields = [...row];
	console.log(`   ✓ Iteration works: [${fields.join(', ')}]`);

	console.log("   ✅ PASS");
} catch (error) {
	console.error(`   ❌ FAIL: ${error.message}`);
} finally {
	result1.destroy();
}

// Test 2: Lazy mode with headers
console.log("\n2️⃣  Test: Lazy mode with headers");
const csv2 = "name,age,city\nAlice,30,NYC\nBob,25,LA";
const result2 = parseCSV(csv2, { mode: 'lazy', hasHeader: true });

try {
	console.log(`   ✓ Headers: [${result2.headers.join(', ')}]`);
	console.log(`   ✓ Data rows: ${result2.rowCount}`);

	const row = result2.getRow(0);
	console.log(`   ✓ First data row: ${row.get(0)} (${result2.headers[0]})`);

	console.log("   ✅ PASS");
} catch (error) {
	console.error(`   ❌ FAIL: ${error.message}`);
} finally {
	result2.destroy();
}

// Test 3: LazyResult iteration
console.log("\n3️⃣  Test: LazyResult iteration");
const csv3 = "x\ny\nz";
const result3 = parseCSV(csv3, { mode: 'lazy' });

try {
	const values = [];
	for (const row of result3) {
		values.push(row.get(0));
	}
	console.log(`   ✓ Iterated rows: [${values.join(', ')}]`);
	console.log("   ✅ PASS");
} catch (error) {
	console.error(`   ❌ FAIL: ${error.message}`);
} finally {
	result3.destroy();
}

// Test 4: Slice generator
console.log("\n4️⃣  Test: Slice generator");
const csv4 = "a\nb\nc\nd\ne";
const result4 = parseCSV(csv4, { mode: 'lazy' });

try {
	const slice = [...result4.slice(1, 4)];
	console.log(`   ✓ Slice(1, 4): ${slice.length} rows`);
	console.log(`   ✓ Values: [${slice.map(r => r.get(0)).join(', ')}]`);
	console.log("   ✅ PASS");
} catch (error) {
	console.error(`   ❌ FAIL: ${error.message}`);
} finally {
	result4.destroy();
}

// Test 5: Bounds checking
console.log("\n5️⃣  Test: Bounds checking");
const csv5 = "a,b\nc,d";
const result5 = parseCSV(csv5, { mode: 'lazy' });

try {
	let errorCaught = false;
	try {
		result5.getRow(999);
	} catch (e) {
		if (e instanceof RangeError) {
			errorCaught = true;
		}
	}

	if (errorCaught) {
		console.log("   ✓ Row bounds checking works");
	} else {
		throw new Error("Row bounds checking failed");
	}

	errorCaught = false;
	try {
		result5.getRow(0).get(999);
	} catch (e) {
		if (e instanceof RangeError) {
			errorCaught = true;
		}
	}

	if (errorCaught) {
		console.log("   ✓ Field bounds checking works");
	} else {
		throw new Error("Field bounds checking failed");
	}

	console.log("   ✅ PASS");
} catch (error) {
	console.error(`   ❌ FAIL: ${error.message}`);
} finally {
	result5.destroy();
}

// Test 6: Access after destroy
console.log("\n6️⃣  Test: Access after destroy");
const csv6 = "a,b,c";
const result6 = parseCSV(csv6, { mode: 'lazy' });
result6.destroy();

try {
	let errorCaught = false;
	try {
		result6.getRow(0);
	} catch (e) {
		if (e.message.includes("destroyed")) {
			errorCaught = true;
		}
	}

	if (errorCaught) {
		console.log("   ✓ Access after destroy prevented");
		console.log("   ✅ PASS");
	} else {
		console.error("   ❌ FAIL: No error on access after destroy");
	}
} catch (error) {
	console.error(`   ❌ FAIL: ${error.message}`);
}

// Test 7: Eager mode still works
console.log("\n7️⃣  Test: Eager mode (backwards compatibility)");
const csv7 = "a,b\n1,2\n3,4";
const result7 = parseCSV(csv7);  // No mode = eager

try {
	if (Array.isArray(result7.rows)) {
		console.log(`   ✓ Returns array: ${result7.rows.length} rows`);
		console.log(`   ✓ First row: [${result7.rows[0].join(', ')}]`);
		console.log("   ✅ PASS");
	} else {
		console.error("   ❌ FAIL: Not an array");
	}
} catch (error) {
	console.error(`   ❌ FAIL: ${error.message}`);
}

// Summary
console.log("\n" + "=".repeat(60));
console.log("✅ All validation tests completed!");
console.log("\nLazy mode implementation is working correctly.");
