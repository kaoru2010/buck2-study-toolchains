def _pict_cucumber_table_impl(ctx: AnalysisContext) -> list[Provider]:
    pict_out_tsv = ctx.actions.declare_output('pict_out.tsv')
    sh = ctx.actions.write(
        "build_step1.sh",
        cmd_args([
            "#!/bin/sh",
            "set -e",
            "set -o pipefail",
            "",
            cmd_args([ctx.attrs.pict_bin[RunInfo], ctx.attrs.src, '>', pict_out_tsv.as_output()], delimiter=" "),
        ]),
        is_executable = True,
    )

    ctx.actions.run(
        cmd_args(
            ["sh", sh],
            hidden = [
                pict_out_tsv.as_output(),
                ctx.attrs.pict_bin[RunInfo],
                ctx.attrs.src,
            ],
        ),
        category = 'pict',
        identifier = 'step1',
        always_print_stderr = True,
    )

    out_file = ctx.actions.declare_output('out.txt')
    build_step2_sh = ctx.actions.write(
        "build_step2.sh",
        cmd_args([
            "#!/bin/sh",
            "set -e",
            "set -o pipefail",
            "",
            cmd_args(["go", "run", ctx.attrs.converter_go_file, pict_out_tsv, out_file.as_output()], delimiter=" "),
        ]),
    )

    ctx.actions.run(
        cmd_args(
            ["sh", build_step2_sh],
            hidden = [
                out_file.as_output(),
                ctx.attrs.converter_go_file,
                pict_out_tsv,
            ],
        ),
        category = 'pict',
        identifier = 'step2',
        always_print_stderr = True,
    )

    return [
        DefaultInfo(
            default_output = out_file,
        ),
        RunInfo(
            args = cmd_args(['cat', out_file]),
        ),
    ]

pict_cucumber_table = rule(
    impl = _pict_cucumber_table_impl,
    attrs = {
        "src": attrs.source(),
        "converter_go_file": attrs.default_only(attrs.source(default = 'buck2_study_toolchains//:convert_tsv_to_cucumber_table.go')),
        "pict_bin": attrs.default_only(attrs.exec_dep(providers = [RunInfo], default = "buck2_study_toolchains//:pict_bin")),
    }
)
