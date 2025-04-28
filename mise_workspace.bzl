def _mise_workspace_impl(ctx: AnalysisContext) -> list[Provider]:
    if type(ctx.attrs.srcs) == type([]):
        # FIXME: We should always use the short_path, but currently that is sometimes blank.
        # See fbcode//buck2/tests/targets/rules/genrule:genrule-dot-input for a test that exposes it.
        symlinks = {src.short_path: src for src in ctx.attrs.srcs}

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

    out_dir = ctx.actions.declare_output("workspace", dir = True)
    build_sh, _ = ctx.actions.write(
        "build.sh",
        cmd_args([
            "#!/bin/sh",
            "set -e",
            "set -o pipefail",
            "",
            cmd_args(["cp", "-a", copied_srcs_dir, out_dir.as_output()], delimiter=" "),
            cmd_args(["cd", out_dir.as_output()], delimiter=" "),
            cmd_args([ctx.attrs.mise_activate], delimiter=" ", relative_to=out_dir),
            cmd_args(["mise", "trust"], delimiter=" "),
            cmd_args(["mise", "install"], delimiter=" "),
            cmd_args([ctx.attrs.cmd], delimiter=" "),
        ]),
        is_executable = True,
        allow_args=True,
    )
    ctx.actions.run(
        cmd_args(["sh", build_sh], hidden = [
            out_dir.as_output(),
            copied_srcs_dir,
            ctx.attrs.mise_activate,
            ctx.attrs.cmd,
        ]),
        category = 'mise_workspace',
        always_print_stderr = True,
    )

    sub_targets = ctx.attrs.sub_targets
    if type(sub_targets) == type([]):
        sub_targets = {
            path: [DefaultInfo(default_output = out_dir.project(path))]
            for path in sub_targets
        }
    elif type(sub_targets) == type({}):
        sub_targets = {
            name: [DefaultInfo(default_outputs = [out_dir.project(path) for path in paths])]
            for name, paths in sub_targets.items()
        }
    else:
        fail("sub_targets must be a list or dict")

    return [
        DefaultInfo(
            default_output = out_dir,
            sub_targets = sub_targets,
        ),
    ]

mise_workspace = rule(
    impl = _mise_workspace_impl,
    attrs = {
        "mise_activate": attrs.string(),
        "srcs": attrs.list(attrs.source(), default = []),
        "cmd": attrs.arg(),
        "sub_targets": attrs.one_of(
            attrs.list(attrs.string()),
            attrs.dict(
                attrs.string(),
                attrs.list(attrs.string()),
            ),
            default = [],
        ),
    },
)
