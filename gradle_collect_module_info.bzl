def _gradle_collect_module_info_impl(ctx: AnalysisContext) -> list[Provider]:
    if type(ctx.attrs.srcs) == type([]):
        # FIXME: We should always use the short_path, but currently that is sometimes blank.
        # See fbcode//buck2/tests/targets/rules/genrule:genrule-dot-input for a test that exposes it.
        symlinks = {(src.short_path.removeprefix(ctx.attrs.strip_prefix) if ctx.attrs.strip_prefix != None else src.short_path): src for src in ctx.attrs.srcs}

        if len(symlinks) != len(ctx.attrs.srcs):
            for src in ctx.attrs.srcs:
                name = src.short_path
                if symlinks[name] != src:
                    msg = "genrule srcs include duplicative name: `{}`. ".format(name)
                    msg += "`{}` conflicts with `{}`".format(symlinks[name].owner, src.owner)
                    fail(msg)
    else:
        symlinks = ctx.attrs.srcs
    copied_srcs_dir = ctx.actions.copied_dir("srcs", symlinks)

    out = ctx.actions.declare_output("module_info.json")
    out_dir = ctx.actions.declare_output("workspace", dir=True)

    mise_activate = [
        cmd_args([ctx.attrs.mise_activate], delimiter=" ", relative_to=out_dir),
        cmd_args(["mise", "trust"], delimiter=" "),
        cmd_args(["mise", "install"], delimiter=" "),
    ] if ctx.attrs.mise_activate != None else "# NOTE: No mise setup because ctx.attrs.mise_activate == None."

    build_sh = ctx.actions.write(
        "build.sh",
        cmd_args([
            "#!/bin/sh",
            "set -euo pipefail",
            "",
            cmd_args(["cp", "-a", copied_srcs_dir, out_dir.as_output()], delimiter=" "),
            cmd_args(["cd", out_dir.as_output()], delimiter=" "),
            "",
            mise_activate,
            "",
            cmd_args(out.as_output(), format="export JSON_OUTPUT_PATH={}"),
            cmd_args(["./gradlew", "-I", ctx.attrs.init_script], delimiter=" "),
        ]),
        is_executable = True,
        absolute=True,
    )

    hidden = [
        out.as_output(),
        out_dir.as_output(),
        copied_srcs_dir,
        ctx.attrs.init_script,
    ]
    if ctx.attrs.mise_activate != None:
        hidden.append(ctx.attrs.mise_activate)

    ctx.actions.run(
        cmd_args(["sh", build_sh], hidden = hidden),
        category = 'mise_workspace',
        always_print_stderr = True,
    )

    return [
        DefaultInfo(
            default_output = out,
        ),
    ]

gradle_collect_module_info = rule(
    impl = _gradle_collect_module_info_impl,
    attrs = {
        "mise_activate": attrs.option(attrs.string(), default = None),
        "srcs": attrs.list(attrs.source(), default = []),
        "strip_prefix": attrs.option(attrs.string(), default = None),
        "init_script": attrs.default_only(attrs.source(default = "buck2_study_toolchains//:gradle_collect_module_info.init.gradle.kts")),
    },
)
