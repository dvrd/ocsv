# OCSV Benchmarks

Performance benchmarks for the OCSV CSV parser.

## Running Benchmarks

### Full Benchmark Suite

Run all benchmarks with different file sizes:

```bash
odin run benchmarks/csv_benchmark.odin -file
```

### With Optimizations

For accurate performance measurements, compile with optimizations:

```bash
odin run benchmarks/csv_benchmark.odin -file -o:speed
```

## Benchmark Configurations

The benchmark suite tests parsing performance with the following file sizes:

| Configuration | Rows | Columns | Approx Size |
|--------------|------|---------|-------------|
| Tiny | 100 | 5 | ~5 KB |
| Small | 1K | 5 | ~50 KB |
| Medium | 10K | 10 | ~1 MB |
| Medium-Large | 50K | 10 | ~5 MB |
| Large | 100K | 10 | ~10 MB |
| Large | 250K | 10 | ~25 MB |
| XLarge | 500K | 15 | ~75 MB |
| XLarge | 1M | 15 | ~150 MB |

## Metrics Measured

- **Write Time**: Time to generate and write CSV to disk
- **Parse Time**: Time to parse CSV file
- **Throughput**: MB/s parsing rate
- **Rows/sec**: Number of rows parsed per second
- **Memory Usage**: Peak memory allocated during parsing

## Example Output

```
CSV PARSING BENCHMARK RESULTS
====================================================================================================
Benchmark                       Rows    File Size   Parse Time      Rows/sec       MB/sec     Memory
----------------------------------------------------------------------------------------------------
Tiny (100 rows)                  100       4.9 KB      0.15 ms         666,667       32.67    0.05 MB
Small (1K rows)                1,000      48.8 KB      0.98 ms       1,020,408       49.80    0.23 MB
Medium (10K rows)             10,000     976.6 KB      8.45 ms       1,183,432       115.56    2.15 MB
Large (100K rows)            100,000       9.5 MB     82.34 ms       1,214,575       115.42   21.45 MB
====================================================================================================
```

## Integration with CI/CD

Benchmarks can be run in CI/CD to track performance regressions over time. See `.github/workflows/` for examples.
