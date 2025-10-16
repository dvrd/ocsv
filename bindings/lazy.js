/**
 * OCSV Lazy Mode - On-demand CSV data access
 *
 * Provides LazyRow and LazyResult classes for efficient access to parsed CSV data
 * stored in native Odin memory, minimizing FFI boundary crossings.
 *
 * @module ocsv/lazy
 */

import { lib } from "./index.js";

/**
 * Lazy row accessor - fields loaded on-demand from native memory.
 *
 * @example
 * const row = new LazyRow(parser, 5000);
 * console.log(row.get(0));      // Access field 0
 * console.log([...row]);        // Iterate all fields
 * console.log(row.toArray());   // Materialize to array
 */
export class LazyRow {
	constructor(parser, rowIndex) {
		this._parser = parser;
		this._rowIndex = rowIndex;
		this._fieldCount = lib.symbols.ocsv_get_field_count(parser, rowIndex);
		this._cache = new Map();  // Field index → value
	}

	// Array-like property
	get length() {
		return this._fieldCount;
	}

	// Field access with memoization
	get(fieldIndex) {
		// Validate bounds
		if (fieldIndex < 0 || fieldIndex >= this._fieldCount) {
			throw new RangeError(`Field ${fieldIndex} out of bounds [0, ${this._fieldCount})`);
		}

		// Check cache first
		if (this._cache.has(fieldIndex)) {
			return this._cache.get(fieldIndex);
		}

		// Fetch from native memory
		const value = lib.symbols.ocsv_get_field(
			this._parser,
			this._rowIndex,
			fieldIndex
		) || "";

		// Cache for future access
		this._cache.set(fieldIndex, value);
		return value;
	}

	// Iterable protocol
	*[Symbol.iterator]() {
		for (let i = 0; i < this._fieldCount; i++) {
			yield this.get(i);
		}
	}

	// Materialize all fields
	toArray() {
		const arr = new Array(this._fieldCount);
		for (let i = 0; i < this._fieldCount; i++) {
			arr[i] = this.get(i);
		}
		return arr;
	}

	// Array-like methods (delegate to toArray)
	map(fn) {
		return this.toArray().map(fn);
	}

	filter(fn) {
		return this.toArray().filter(fn);
	}

	slice(start, end) {
		const result = [];
		const s = start ?? 0;
		const e = end ?? this._fieldCount;
		for (let i = s; i < e; i++) {
			result.push(this.get(i));
		}
		return result;
	}

	// Inspection
	[Symbol.for('nodejs.util.inspect.custom')]() {
		return `LazyRow(row=${this._rowIndex}, fields=${this._fieldCount})`;
	}
}

/**
 * Lazy result accessor - rows loaded on-demand from native memory.
 * Uses LRU cache to keep 1000 most recently accessed rows.
 *
 * CRITICAL: Owns parser pointer - must call destroy() when done.
 *
 * @example
 * const result = parseCSV(data, { mode: 'lazy' });
 * try {
 *   const row = result.getRow(5000000);
 *   console.log(row.get(0));
 * } finally {
 *   result.destroy();  // MUST cleanup
 * }
 */
export class LazyResult {
	constructor(parser, rowCount, headers, options) {
		this._parser = parser;
		this._rowCount = rowCount;
		this._headers = headers;
		this._options = options;
		this._rowCache = new Map();  // LRU cache: rowIndex → LazyRow
		this._destroyed = false;
		this._maxCacheSize = 1000;  // Keep 1000 hot rows
	}

	get rowCount() {
		return this._rowCount;
	}

	get headers() {
		return this._headers;
	}

	// Row access with LRU caching
	getRow(index) {
		if (this._destroyed) {
			throw new Error("LazyResult has been destroyed");
		}

		// Validate bounds
		if (index < 0 || index >= this._rowCount) {
			throw new RangeError(`Row ${index} out of bounds [0, ${this._rowCount})`);
		}

		// Check cache (moves to end if exists)
		if (this._rowCache.has(index)) {
			const row = this._rowCache.get(index);
			// Move to end (most recently used)
			this._rowCache.delete(index);
			this._rowCache.set(index, row);
			return row;
		}

		// Create new LazyRow
		const row = new LazyRow(this._parser, index);
		this._rowCache.set(index, row);

		// Evict LRU if cache full
		if (this._rowCache.size > this._maxCacheSize) {
			const firstKey = this._rowCache.keys().next().value;
			this._rowCache.delete(firstKey);
		}

		return row;
	}

	// Iterable protocol
	*[Symbol.iterator]() {
		for (let i = 0; i < this._rowCount; i++) {
			yield this.getRow(i);
		}
	}

	// Efficient range access (generator)
	*slice(start, end) {
		const s = start ?? 0;
		const e = end ?? this._rowCount;

		for (let i = s; i < e; i++) {
			if (i < 0 || i >= this._rowCount) break;
			yield this.getRow(i);
		}
	}

	// Materialize all rows (backwards compat)
	toArray() {
		const rows = new Array(this._rowCount);
		for (let i = 0; i < this._rowCount; i++) {
			rows[i] = this.getRow(i).toArray();
		}
		return rows;
	}

	// Cleanup
	destroy() {
		if (!this._destroyed) {
			if (this._parser) {
				lib.symbols.ocsv_parser_destroy(this._parser);
				this._parser = null;
			}
			this._rowCache.clear();
			this._destroyed = true;
		}
	}

	// Inspection
	[Symbol.for('nodejs.util.inspect.custom')]() {
		return `LazyResult(rows=${this._rowCount}, cached=${this._rowCache.size}, destroyed=${this._destroyed})`;
	}
}
