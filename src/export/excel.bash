export_excel() {
    _param output --default "export.xlsx" --help "Output .xlsx file path"
    _param sheet  --default "Sheet1"      --help "Sheet name (appends if file exists)"
    _param input  --path file             --help "Input TSV file (default: stdin)"
    _param_parse "$@" || return 1

    if [[ -n "$input" ]]; then
        _exec_python export excel.py --output "$output" --sheet "$sheet" < "$input"
    else
        _exec_python export excel.py --output "$output" --sheet "$sheet"
    fi
}

_complete_params "export_excel" "Convert TSV input to a formatted Excel (.xlsx) file" output sheet input
