/**
 * Unit tests for LazyRow class
 */

import { test, expect, beforeEach, afterEach } from "bun:test";
import { ptr } from "bun:ffi";
import { LazyRow } from "../lazy.js";
import { Parser, lib } from "../index.js";

let parser;
let parserPtr;
let testCSV;

beforeEach(() => {
	// Test CSV with 3 rows, 12 fields each (matching benchmark structure)
	testCSV = `1,Susan Thomas,640 Rodriguez Forge Suite 645,Michaelview,MA,64206,+1-382-631-3736,susan41@example.org,2018-06-25,Silver,2621.07,ftp://martinez.biz/
2,Michelle Avery,9677 Wagner Mission,Andrewport,TN,85254,892.728.8285,candacewilliams@example.com,2011-02-09,Platinum,6720.80,http://www.douglas.com/
3,Mary Garcia,4084 Meyers Plains,Mooreborough,NE,49517,+1-658-592-7967,cynthiawilliams@example.net,2010-11-26,Gold,9447.93,https://carpenter.com/`;

	// Create parser and parse CSV
	parser = new Parser();
	const buffer = Buffer.from(testCSV + '\0');
	const parseResult = lib.symbols.ocsv_parse_string(parser.parser, ptr(buffer), testCSV.length);

	if (parseResult !== 0) {
		throw new Error("Failed to parse test CSV");
	}

	// Store parser pointer for LazyRow
	parserPtr = parser.parser;
});

afterEach(() => {
	if (parser) {
		parser.destroy();
		parser = null;
		parserPtr = null;
	}
});

test("LazyRow - field access", () => {
	const row = new LazyRow(parserPtr, 0);

	expect(row.length).toBe(12);
	expect(row.get(0)).toBe("1");
	expect(row.get(1)).toBe("Susan Thomas");
	expect(row.get(2)).toBe("640 Rodriguez Forge Suite 645");
});

test("LazyRow - iteration", () => {
	const row = new LazyRow(parserPtr, 0);
	const fields = [...row];

	expect(fields.length).toBe(12);
	expect(fields[0]).toBe("1");
	expect(fields[1]).toBe("Susan Thomas");
});

test("LazyRow - caching", () => {
	const row = new LazyRow(parserPtr, 0);

	const value1 = row.get(5);
	const value2 = row.get(5);

	// Should return same string (cached)
	expect(value1).toBe(value2);
	expect(value1).toBe("64206");
});

test("LazyRow - bounds checking - negative index", () => {
	const row = new LazyRow(parserPtr, 0);

	expect(() => row.get(-1)).toThrow(RangeError);
	expect(() => row.get(-1)).toThrow("out of bounds");
});

test("LazyRow - bounds checking - too large index", () => {
	const row = new LazyRow(parserPtr, 0);

	expect(() => row.get(999)).toThrow(RangeError);
	expect(() => row.get(999)).toThrow("out of bounds");
});

test("LazyRow - toArray", () => {
	const row = new LazyRow(parserPtr, 1);
	const arr = row.toArray();

	expect(arr).toBeArrayOfSize(12);
	expect(arr[0]).toBe("2");
	expect(arr[1]).toBe("Michelle Avery");
});

test("LazyRow - map method", () => {
	const row = new LazyRow(parserPtr, 0);
	const uppercased = row.map((field, idx) => field.toUpperCase());

	expect(uppercased[0]).toBe("1");
	expect(uppercased[1]).toBe("SUSAN THOMAS");
});

test("LazyRow - filter method", () => {
	const row = new LazyRow(parserPtr, 0);
	const filtered = row.filter(field => field.includes("@"));

	expect(filtered.length).toBe(1);
	expect(filtered[0]).toBe("susan41@example.org");
});

test("LazyRow - slice method", () => {
	const row = new LazyRow(parserPtr, 0);
	const sliced = row.slice(0, 3);

	expect(sliced.length).toBe(3);
	expect(sliced[0]).toBe("1");
	expect(sliced[1]).toBe("Susan Thomas");
	expect(sliced[2]).toBe("640 Rodriguez Forge Suite 645");
});

test("LazyRow - slice with defaults", () => {
	const row = new LazyRow(parserPtr, 0);
	const sliced = row.slice(10); // From 10 to end

	expect(sliced.length).toBe(2);
	expect(sliced[0]).toBe("2621.07");
});

test("LazyRow - inspect custom", () => {
	const row = new LazyRow(parserPtr, 0);
	const inspectSymbol = Symbol.for('nodejs.util.inspect.custom');
	const output = row[inspectSymbol]();

	expect(output).toContain("LazyRow");
	expect(output).toContain("row=0");
	expect(output).toContain("fields=12");
});

test("LazyRow - for...of loop", () => {
	const row = new LazyRow(parserPtr, 2);
	const collected = [];

	for (const field of row) {
		collected.push(field);
	}

	expect(collected.length).toBe(12);
	expect(collected[0]).toBe("3");
	expect(collected[1]).toBe("Mary Garcia");
});

test("LazyRow - access different rows", () => {
	const row0 = new LazyRow(parserPtr, 0);
	const row1 = new LazyRow(parserPtr, 1);
	const row2 = new LazyRow(parserPtr, 2);

	expect(row0.get(0)).toBe("1");
	expect(row1.get(0)).toBe("2");
	expect(row2.get(0)).toBe("3");

	expect(row0.get(1)).toBe("Susan Thomas");
	expect(row1.get(1)).toBe("Michelle Avery");
	expect(row2.get(1)).toBe("Mary Garcia");
});
