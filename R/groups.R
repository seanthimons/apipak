tool_groups <-
  list(
    schema = c(
      "extract_referenced_schemas",
      "filter_components_by_refs",
      "preprocess_schema",
      "validate_schema_ref",
      "resolve_schema_ref",
      "detect_schema_version",
      "extract_swagger2_body_schema",
      "resolve_swagger2_definition_ref",
      "extract_body_properties",
      "extract_query_params_with_refs"
    ),
    paths = "strip_curly_params",
    inventory = "find_endpoint_usages_base",
    scaffold = c("has_protected_lifecycle", "scaffold_files"),
    test_inventory = c(
      "tg_strip_namespace_quotes",
      "tg_parse_namespace_exports",
      "tg_call_name",
      "tg_all_call_names",
      "tg_find_function_defs_in_file",
      "tg_find_exported_function_defs",
      "tg_inventory_wrappers"
    ),
    test_scaffold = c(
      "tg_list_test_files",
      "tg_classify_test_file",
      "tg_remove_legacy_generated_tests",
      "tg_remove_obsolete_generated_tests",
      "tg_format_generated_text",
      "tg_write_generated_tests",
      "tg_scaffold_generated_tests"
    ),
    test_validation = c(
      "tg_validate_generated_text",
      "tg_validate_generated_files",
      "tg_check_generated_tests_current"
    ),
    test_helpers = c(
      "%tg||%",
      "tg_norm_path",
      "tg_rel_path",
      "tg_file_path",
      "tg_read_lines",
      "tg_read_text",
      "tg_without_terminal_newline",
      "tg_canonical_r_code",
      "tg_generated_text_identical",
      "tg_text_header_lines",
      "tg_has_generated_header",
      "tg_has_legacy_metadata_header",
      "tg_test_file_for",
      "tg_cli_info",
      "tg_cli_success",
      "tg_cli_warning",
      "tg_cli_abort"
    ),
    ast = c(
      "tg_find_calls",
      "tg_deparse_expr",
      "tg_literal_value",
      "tg_symbol_value",
      "tg_call_args",
      "tg_named_call_args",
      "tg_formal_records"
    ),
    runner = c(
      "empty_scaffold",
      "derive_fn_from_file",
      "resolve_collisions",
      "run_generator",
      "is_operation_implemented",
      "endpoint_coverage"
    ),
    parser = c(
      "sanitize_name",
      "method_path_name",
      "dedup_params",
      "param_names",
      "param_metadata",
      "get_response_schema_type",
      "extract_body_schema_metadata",
      "order_path_by_route",
      "detect_pagination",
      "openapi_to_spec"
    ),
    drift = c("extract_function_params", "detect_parameter_drift"),
    diff = c(
      "classify_param_change",
      "diff_single_schema",
      "diff_schemas",
      "format_diff_markdown",
      "count_diff_changes"
    )
  )
