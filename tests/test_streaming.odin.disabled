package tests

import "core:testing"
import "core:fmt"
import "core:os"
import ocsv "../src"

// Test data for streaming tests
Test_Context :: struct {
	rows_collected: [dynamic][]string,
	row_count:      int,
	should_stop_at: int,  // Row number to stop at (0 = don't stop)
	errors:         [dynamic]ocsv.Error_Info,
}

// Basic streaming callback that collects all rows
collect_rows_callback :: proc(row: []string, row_num: int, user_data: rawptr) -> bool {
	ctx := cast(^Test_Context)user_data

	// Make a copy of the row
	row_copy := make([]string, len(row))
	for field, i in row {
		row_copy[i] = fmt.aprintf("%s", field)
	}
	append(&ctx.rows_collected, row_copy)
	ctx.row_count += 1

	// Stop at specific row if configured
	if ctx.should_stop_at > 0 && ctx.row_count >= ctx.should_stop_at {
		return false
	}

	return true
}

// Error callback that collects errors
collect_errors_callback :: proc(error: ocsv.Error_Info, row_num: int, user_data: rawptr) -> bool {
	ctx := cast(^Test_Context)user_data
	append(&ctx.errors, error)
	return true  // Continue parsing
}

// Cleanup test context
destroy_test_context :: proc(ctx: ^Test_Context) {
	for row in ctx.rows_collected {
		for field in row {
			delete(field)
		}
		delete(row)
	}
	delete(ctx.rows_collected)

	// Don't delete error messages - they might be string literals
	delete(ctx.errors)
}

@(test)
test_streaming_basic :: proc(t: ^testing.T) {
	// Create test CSV file
	test_file := "test_streaming_basic.csv"
	csv_data := "name,age,city\nAlice,30,NYC\nBob,25,SF\nCharlie,35,LA\n"
	os.write_entire_file(test_file, transmute([]byte)csv_data)
	defer os.remove(test_file)

	// Setup streaming config
	ctx := Test_Context{}
	defer destroy_test_context(&ctx)

	config := ocsv.default_streaming_config(collect_rows_callback)
	config.user_data = &ctx

	// Parse file
	rows_processed, ok := ocsv.parse_csv_stream(config, test_file)

	testing.expect(t, ok, "Streaming parse should succeed")
	testing.expect_value(t, rows_processed, 4)  // Header + 3 data rows
	testing.expect_value(t, ctx.row_count, 4)
	testing.expect_value(t, len(ctx.rows_collected), 4)

	// Verify header row
	testing.expect_value(t, len(ctx.rows_collected[0]), 3)
	testing.expect_value(t, ctx.rows_collected[0][0], "name")
	testing.expect_value(t, ctx.rows_collected[0][1], "age")
	testing.expect_value(t, ctx.rows_collected[0][2], "city")

	// Verify first data row
	testing.expect_value(t, ctx.rows_collected[1][0], "Alice")
	testing.expect_value(t, ctx.rows_collected[1][1], "30")
	testing.expect_value(t, ctx.rows_collected[1][2], "NYC")
}

@(test)
test_streaming_large_file :: proc(t: ^testing.T) {
	// Create a larger CSV file (1000 rows - reduced for faster testing)
	test_file := "test_streaming_large.csv"

	// Write header
	handle, err := os.open(test_file, os.O_CREATE | os.O_WRONLY | os.O_TRUNC, 0o644)
	testing.expect(t, err == 0, "Should create test file")
	defer os.close(handle)

	os.write_string(handle, "id,value,description\n")

	// Write 1000 rows
	for i in 1..=1000 {
		line := fmt.aprintf("%d,%.2f,Description for row %d\n", i, f64(i) * 1.5, i)
		os.write_string(handle, line)
		delete(line)
	}
	os.close(handle)
	defer os.remove(test_file)

	// Setup streaming config with small chunk size to test chunking
	ctx := Test_Context{}
	defer destroy_test_context(&ctx)

	config := ocsv.default_streaming_config(collect_rows_callback)
	config.chunk_size = 1024  // 1KB chunks
	config.user_data = &ctx

	// Parse file
	rows_processed, ok := ocsv.parse_csv_stream(config, test_file)

	testing.expect(t, ok, "Streaming parse should succeed")
	testing.expect_value(t, rows_processed, 1001)  // Header + 1000 rows
	testing.expect_value(t, ctx.row_count, 1001)

	// Verify first and last data rows
	testing.expect_value(t, ctx.rows_collected[1][0], "1")
	testing.expect_value(t, ctx.rows_collected[1000][0], "1000")
}

@(test)
test_streaming_quoted_fields :: proc(t: ^testing.T) {
	// Create test CSV with quoted fields (including multiline)
	test_file := "test_streaming_quoted.csv"
	csv_data := `product,price,description
"Widget A",19.99,"A great widget, with comma"
"Gadget B",29.99,"Essential gadget
with newline"
"Tool C",39.99,"Simple tool"
`
	os.write_entire_file(test_file, transmute([]byte)csv_data)
	defer os.remove(test_file)

	// Setup streaming config
	ctx := Test_Context{}
	defer destroy_test_context(&ctx)

	config := ocsv.default_streaming_config(collect_rows_callback)
	config.chunk_size = 32  // Very small chunks to test boundary handling
	config.user_data = &ctx

	// Parse file
	rows_processed, ok := ocsv.parse_csv_stream(config, test_file)

	testing.expect(t, ok, "Streaming parse should succeed")
	testing.expect_value(t, rows_processed, 4)

	// Verify row with comma in quoted field
	testing.expect_value(t, ctx.rows_collected[1][0], "Widget A")
	testing.expect_value(t, ctx.rows_collected[1][2], "A great widget, with comma")

	// Verify row with newline in quoted field
	testing.expect_value(t, ctx.rows_collected[2][0], "Gadget B")
	testing.expect_value(t, ctx.rows_collected[2][2], "Essential gadget\nwith newline")
}

@(test)
test_streaming_early_stop :: proc(t: ^testing.T) {
	// Create test CSV file
	test_file := "test_streaming_stop.csv"
	csv_data := "name,age\nAlice,30\nBob,25\nCharlie,35\nDave,40\nEve,45\n"
	os.write_entire_file(test_file, transmute([]byte)csv_data)
	defer os.remove(test_file)

	// Setup streaming config that stops after 3 rows
	ctx := Test_Context{should_stop_at = 3}
	defer destroy_test_context(&ctx)

	config := ocsv.default_streaming_config(collect_rows_callback)
	config.user_data = &ctx

	// Parse file
	rows_processed, ok := ocsv.parse_csv_stream(config, test_file)

	testing.expect(t, !ok, "Should stop early")
	testing.expect_value(t, ctx.row_count, 3)
	testing.expect_value(t, len(ctx.rows_collected), 3)
}

@(test)
test_streaming_empty_fields :: proc(t: ^testing.T) {
	// Create test CSV with empty fields
	test_file := "test_streaming_empty.csv"
	csv_data := "a,b,c\n1,,3\n,5,\n,,\n"
	os.write_entire_file(test_file, transmute([]byte)csv_data)
	defer os.remove(test_file)

	ctx := Test_Context{}
	defer destroy_test_context(&ctx)

	config := ocsv.default_streaming_config(collect_rows_callback)
	config.user_data = &ctx

	rows_processed, ok := ocsv.parse_csv_stream(config, test_file)

	testing.expect(t, ok, "Should parse empty fields")
	testing.expect_value(t, rows_processed, 4)

	// Row 1: "1,,3"
	testing.expect_value(t, ctx.rows_collected[1][0], "1")
	testing.expect_value(t, ctx.rows_collected[1][1], "")
	testing.expect_value(t, ctx.rows_collected[1][2], "3")

	// Row 3: ",,"
	testing.expect_value(t, ctx.rows_collected[3][0], "")
	testing.expect_value(t, ctx.rows_collected[3][1], "")
	testing.expect_value(t, ctx.rows_collected[3][2], "")
}

@(test)
test_streaming_utf8 :: proc(t: ^testing.T) {
	// Create test CSV with UTF-8 characters
	test_file := "test_streaming_utf8.csv"
	csv_data := "name,city,emoji\n田中,東京,😀\nヤマダ,大阪,🎉\n"
	os.write_entire_file(test_file, transmute([]byte)csv_data)
	defer os.remove(test_file)

	ctx := Test_Context{}
	defer destroy_test_context(&ctx)

	config := ocsv.default_streaming_config(collect_rows_callback)
	config.chunk_size = 16  // Small chunks to test UTF-8 boundary handling
	config.user_data = &ctx

	rows_processed, ok := ocsv.parse_csv_stream(config, test_file)

	testing.expect(t, ok, "Should parse UTF-8")
	testing.expect_value(t, rows_processed, 3)

	// Verify UTF-8 data
	testing.expect_value(t, ctx.rows_collected[1][0], "田中")
	testing.expect_value(t, ctx.rows_collected[1][1], "東京")
	testing.expect_value(t, ctx.rows_collected[1][2], "😀")
}

@(test)
test_streaming_comments :: proc(t: ^testing.T) {
	// Create test CSV with comments
	test_file := "test_streaming_comments.csv"
	csv_data := "# This is a comment\nname,age\n# Another comment\nAlice,30\nBob,25\n"
	os.write_entire_file(test_file, transmute([]byte)csv_data)
	defer os.remove(test_file)

	ctx := Test_Context{}
	defer destroy_test_context(&ctx)

	config := ocsv.default_streaming_config(collect_rows_callback)
	config.user_data = &ctx

	rows_processed, ok := ocsv.parse_csv_stream(config, test_file)

	testing.expect(t, ok, "Should skip comments")
	testing.expect_value(t, rows_processed, 3)  // Header + 2 data rows (comments skipped)
	testing.expect_value(t, len(ctx.rows_collected), 3)

	testing.expect_value(t, ctx.rows_collected[0][0], "name")
	testing.expect_value(t, ctx.rows_collected[1][0], "Alice")
	testing.expect_value(t, ctx.rows_collected[2][0], "Bob")
}

@(test)
test_streaming_error_callback :: proc(t: ^testing.T) {
	// Create test CSV with unterminated quote (strict mode)
	test_file := "test_streaming_error.csv"
	csv_data := "name,age\nAlice,30\n\"Bob,25\n"  // Unterminated quote
	os.write_entire_file(test_file, transmute([]byte)csv_data)
	defer os.remove(test_file)

	ctx := Test_Context{}
	defer destroy_test_context(&ctx)

	config := ocsv.default_streaming_config(collect_rows_callback)
	config.error_callback = collect_errors_callback
	config.user_data = &ctx

	rows_processed, ok := ocsv.parse_csv_stream(config, test_file)

	testing.expect(t, !ok, "Should fail on unterminated quote")
	testing.expect(t, len(ctx.errors) > 0, "Should have error")
	testing.expect_value(t, ctx.errors[0].code, ocsv.Parse_Error.Unterminated_Quote)
}

@(test)
test_streaming_relaxed_mode :: proc(t: ^testing.T) {
	// Create test CSV with malformed quotes
	test_file := "test_streaming_relaxed.csv"
	csv_data := "name,age\nAlice,30\n\"Bob,25\n"  // Unterminated quote
	os.write_entire_file(test_file, transmute([]byte)csv_data)
	defer os.remove(test_file)

	ctx := Test_Context{}
	defer destroy_test_context(&ctx)

	config := ocsv.default_streaming_config(collect_rows_callback)
	config.parser_config.relaxed = true
	config.user_data = &ctx

	rows_processed, ok := ocsv.parse_csv_stream(config, test_file)

	testing.expect(t, ok, "Should succeed in relaxed mode")
	testing.expect_value(t, rows_processed, 3)
}

@(test)
test_streaming_custom_delimiter :: proc(t: ^testing.T) {
	// Create TSV (tab-separated) file
	test_file := "test_streaming_tsv.csv"
	csv_data := "name\tage\tcity\nAlice\t30\tNYC\nBob\t25\tSF\n"
	os.write_entire_file(test_file, transmute([]byte)csv_data)
	defer os.remove(test_file)

	ctx := Test_Context{}
	defer destroy_test_context(&ctx)

	config := ocsv.default_streaming_config(collect_rows_callback)
	config.parser_config.delimiter = '\t'
	config.user_data = &ctx

	rows_processed, ok := ocsv.parse_csv_stream(config, test_file)

	testing.expect(t, ok, "Should parse TSV")
	testing.expect_value(t, rows_processed, 3)
	testing.expect_value(t, ctx.rows_collected[0][0], "name")
	testing.expect_value(t, ctx.rows_collected[1][1], "30")
}

// Schema validation streaming tests

Typed_Row_Context :: struct {
	typed_rows:     [dynamic][]ocsv.Typed_Value,
	row_count:      int,
	validation_errors: [dynamic]ocsv.Validation_Error,
}

destroy_typed_context :: proc(ctx: ^Typed_Row_Context) {
	for row in ctx.typed_rows {
		delete(row)
	}
	delete(ctx.typed_rows)
	delete(ctx.validation_errors)
}

schema_callback :: proc(
	typed_row: []ocsv.Typed_Value,
	row_num: int,
	validation_result: ^ocsv.Validation_Result,
	user_data: rawptr,
) -> bool {
	ctx := cast(^Typed_Row_Context)user_data

	// Copy typed row
	row_copy := make([]ocsv.Typed_Value, len(typed_row))
	copy(row_copy, typed_row)
	append(&ctx.typed_rows, row_copy)
	ctx.row_count += 1

	// Collect validation errors
	for err in validation_result.errors {
		append(&ctx.validation_errors, err)
	}

	return true
}

@(test)
test_streaming_with_schema :: proc(t: ^testing.T) {
	// Create test CSV file
	test_file := "test_streaming_schema.csv"
	csv_data := "name,age,price\nAlice,30,19.99\nBob,25,29.99\n"
	os.write_entire_file(test_file, transmute([]byte)csv_data)
	defer os.remove(test_file)

	// Create schema
	schema := ocsv.schema_create([]ocsv.Column_Schema{
		{name = "name", col_type = .String, required = true},
		{name = "age", col_type = .Int, required = true, min_value = 0, max_value = 150},
		{name = "price", col_type = .Float, required = true, min_value = 0.0},
	}, skip_header = true)

	ctx := Typed_Row_Context{}
	defer destroy_typed_context(&ctx)

	config := ocsv.default_streaming_config(nil)
	config.schema = &schema
	config.schema_callback = schema_callback
	config.user_data = &ctx

	rows_processed, ok := ocsv.parse_csv_stream(config, test_file)

	testing.expect(t, ok, "Should parse with schema")
	testing.expect_value(t, rows_processed, 3)  // Header + 2 data rows
	testing.expect_value(t, ctx.row_count, 2)  // Schema skips header

	// Verify typed values
	testing.expect(t, ctx.typed_rows[0][0].(string) == "Alice", "Should have string")
	testing.expect(t, ctx.typed_rows[0][1].(i64) == 30, "Should have int")
	testing.expect(t, ctx.typed_rows[0][2].(f64) == 19.99, "Should have float")
}

@(test)
test_streaming_schema_validation_errors :: proc(t: ^testing.T) {
	// Create test CSV with invalid data
	test_file := "test_streaming_schema_errors.csv"
	csv_data := "name,age,price\nAlice,200,19.99\nBob,25,-5.0\n"  // age too high, price negative
	os.write_entire_file(test_file, transmute([]byte)csv_data)
	defer os.remove(test_file)

	schema := ocsv.schema_create([]ocsv.Column_Schema{
		{name = "name", col_type = .String, required = true},
		{name = "age", col_type = .Int, required = true, min_value = 0, max_value = 150},
		{name = "price", col_type = .Float, required = true, min_value = 0.0},
	}, skip_header = true)

	// Collect errors through error callback
	ctx := Test_Context{}
	defer destroy_test_context(&ctx)

	config := ocsv.default_streaming_config(collect_rows_callback)
	config.schema = &schema
	config.error_callback = collect_errors_callback
	config.user_data = &ctx

	rows_processed, ok := ocsv.parse_csv_stream(config, test_file)

	testing.expect(t, ok, "Should complete parsing")
	testing.expect(t, len(ctx.errors) > 0, "Should have validation errors")
}

@(test)
test_streaming_field_too_large :: proc(t: ^testing.T) {
	// Create test CSV with large field
	test_file := "test_streaming_large_field.csv"

	handle, err := os.open(test_file, os.O_CREATE | os.O_WRONLY | os.O_TRUNC, 0o644)
	testing.expect(t, err == 0, "Should create test file")
	defer os.close(handle)

	// Write header
	os.write_string(handle, "name,data\n")

	// Write row with very large field (>1KB)
	os.write_string(handle, "Alice,")
	for i in 0..<2000 {
		os.write_string(handle, "x")
	}
	os.write_string(handle, "\n")
	os.close(handle)
	defer os.remove(test_file)

	ctx := Test_Context{}
	defer destroy_test_context(&ctx)

	config := ocsv.default_streaming_config(collect_rows_callback)
	config.max_field_size = 1000  // 1KB limit
	config.error_callback = collect_errors_callback
	config.user_data = &ctx

	rows_processed, ok := ocsv.parse_csv_stream(config, test_file)

	testing.expect(t, !ok, "Should fail on large field")
	testing.expect(t, len(ctx.errors) > 0, "Should have error")
	testing.expect_value(t, ctx.errors[0].code, ocsv.Parse_Error.Max_Field_Size_Exceeded)
}

@(test)
test_streaming_file_not_found :: proc(t: ^testing.T) {
	ctx := Test_Context{}
	defer destroy_test_context(&ctx)

	config := ocsv.default_streaming_config(collect_rows_callback)
	config.error_callback = collect_errors_callback
	config.user_data = &ctx

	rows_processed, ok := ocsv.parse_csv_stream(config, "nonexistent_file.csv")

	testing.expect(t, !ok, "Should fail on missing file")
	testing.expect(t, len(ctx.errors) > 0, "Should have error")
	testing.expect_value(t, ctx.errors[0].code, ocsv.Parse_Error.File_Not_Found)
}

@(test)
test_streaming_chunk_boundary :: proc(t: ^testing.T) {
	// Create CSV where quoted field spans chunk boundaries
	test_file := "test_streaming_boundary.csv"
	csv_data := `name,description
Alice,"This is a very long description that will definitely span multiple chunks when we use a small chunk size for testing purposes"
Bob,"Short"
`
	os.write_entire_file(test_file, transmute([]byte)csv_data)
	defer os.remove(test_file)

	ctx := Test_Context{}
	defer destroy_test_context(&ctx)

	config := ocsv.default_streaming_config(collect_rows_callback)
	config.chunk_size = 32  // Very small chunks
	config.user_data = &ctx

	rows_processed, ok := ocsv.parse_csv_stream(config, test_file)

	testing.expect(t, ok, "Should handle chunk boundaries")
	testing.expect_value(t, rows_processed, 3)
	testing.expect(t, len(ctx.rows_collected[1][1]) > 50, "Long description should be complete")
}

@(test)
test_streaming_performance_1k_rows :: proc(t: ^testing.T) {
	// Create file for performance testing (1k rows - fast for CI)
	test_file := "test_streaming_1k.csv"

	handle, err := os.open(test_file, os.O_CREATE | os.O_WRONLY | os.O_TRUNC, 0o644)
	testing.expect(t, err == 0, "Should create test file")
	defer os.close(handle)

	os.write_string(handle, "id,value,description\n")

	for i in 1..=1000 {
		line := fmt.aprintf("%d,%.2f,Row %d\n", i, f64(i) * 1.5, i)
		os.write_string(handle, line)
		delete(line)
	}
	os.close(handle)
	defer os.remove(test_file)

	// Count rows without storing them (memory efficient)
	row_counter := 0
	count_callback :: proc(row: []string, row_num: int, user_data: rawptr) -> bool {
		counter := cast(^int)user_data
		counter^ += 1
		return true
	}

	config := ocsv.default_streaming_config(count_callback)
	config.user_data = &row_counter

	rows_processed, ok := ocsv.parse_csv_stream(config, test_file)

	testing.expect(t, ok, "Should parse 1k rows")
	testing.expect_value(t, rows_processed, 1001)
	testing.expect_value(t, row_counter, 1001)
}
