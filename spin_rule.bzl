# spin_rule.bzl

def _spin_rule_impl(ctx: AnalysisContext) -> list[Provider]:
    build_dir = ctx.actions.declare_output("build", dir = True)

    sh = ctx.actions.write(
        "spin_wrapper.sh",
        cmd_args([
            "#!/bin/sh",
            "set -e",
            "",
            cmd_args(["mkdir", build_dir.as_output()], delimiter=" "),
            cmd_args(["cp", ctx.attrs.src, build_dir], delimiter=" "),
            cmd_args(['('], delimiter=" "),
            cmd_args(["  cd", build_dir], delimiter=" "),
            cmd_args(['  ', ctx.attrs.spin_bin[RunInfo], "-run", ctx.attrs.src.basename], delimiter=" ", relative_to = build_dir),
            cmd_args([')'], delimiter=" "),
        ]),
        is_executable = True,
    )
    ctx.actions.run(cmd_args(["sh", sh], hidden = [build_dir.as_output(), ctx.attrs.spin_bin[RunInfo], ctx.attrs.src]), category = 'spin')

    test_sh = ctx.actions.write(
        "spin_test.sh",
        cmd_args([
            "#!/bin/sh",
            "set -e",
            "",
            cmd_args(['if', '[[', '!', '-f', cmd_args(build_dir.project(ctx.attrs.src.basename), format='{}.trail'), ']];', 'then'], delimiter=" "),
            cmd_args(["  echo", "Show state table as Dot format:", build_dir.project('pan'), '-D'], delimiter=" "),
            '  exit 0',
            'fi',
            '',
            cmd_args(["cd", build_dir], delimiter=" "),
            'echo',
            cmd_args([ctx.attrs.spin_bin[RunInfo], "-run", ctx.attrs.src.basename], delimiter=" ", relative_to = build_dir),
            'echo',
            cmd_args([ctx.attrs.spin_bin[RunInfo], "-g", "-l", "-s", "-r", "-p", "-t", ctx.attrs.src.basename], delimiter=" ", relative_to = build_dir),
            "exit 1",
        ]),
        is_executable = True,
    )
    return [
        DefaultInfo(
            default_output = build_dir,
            sub_targets = {
                "pan": [
                    DefaultInfo(default_outputs = [build_dir.project('pan')]),
                ],
            },
        ),
        ExternalRunnerTestInfo(
            type = "spin_test",
            command = [cmd_args(["sh", test_sh], hidden = [build_dir, ctx.attrs.spin_bin[RunInfo], ctx.attrs.src])],
        ),
    ]

spin_rule = rule(
    impl = _spin_rule_impl,
    attrs = {
        "src": attrs.source(),
        "spin_bin": attrs.default_only(attrs.exec_dep(providers = [RunInfo], default = "@toolchains//:spin_bin")),
    }
)
