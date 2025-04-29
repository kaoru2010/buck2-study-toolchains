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
            "set -euo pipefail",
            "",
            cmd_args(["cp", "-a", copied_srcs_dir, out_dir.as_output()], delimiter=" "),
            cmd_args(["cd", out_dir.as_output()], delimiter=" "),
            cmd_args([ctx.attrs.mise_activate], delimiter=" ", relative_to=out_dir),
            cmd_args(["mise", "trust"], delimiter=" "),
            cmd_args(["mise", "install"], delimiter=" "),
            "",
            ctx.attrs.build_cmds,
        ]),
        is_executable = True,
        allow_args=True,
    )
    ctx.actions.run(
        cmd_args(["sh", build_sh], hidden = [
            out_dir.as_output(),
            copied_srcs_dir,
            ctx.attrs.mise_activate,
            ctx.attrs.build_cmds,
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

    providers = []

    if len(ctx.attrs.run_cmds) > 0:
        run_sh, _ = ctx.actions.write(
            "run.sh",
            cmd_args([
                "#!/bin/sh",
                "set -euo pipefail",
                "",
                cmd_args(["cd", out_dir.as_output()], delimiter=" "),
                cmd_args([ctx.attrs.mise_activate], delimiter=" "),
                "",
                ctx.attrs.run_cmds,
            ]),
            is_executable = True,
            allow_args=True,
            absolute=True,
        )
        providers.append(
            RunInfo(
                args = [cmd_args(["sh", run_sh], hidden = [
                    out_dir,
                    ctx.attrs.mise_activate,
                    ctx.attrs.run_cmds,
                ])],
            ),
        )

    if len(ctx.attrs.test_cmds) > 0:
        test_sh, _ = ctx.actions.write(
            "test.sh",
            cmd_args([
                "#!/bin/sh",
                "set -euo pipefail",
                "",
                cmd_args(["cd", out_dir.as_output()], delimiter=" "),
                cmd_args([ctx.attrs.mise_activate], delimiter=" "),
                "",
                ctx.attrs.test_cmds,
            ]),
            is_executable = True,
            allow_args=True,
            absolute=True,
        )
        providers.append(
            ExternalRunnerTestInfo(
                type = "mise_workspace_test",
                command = [cmd_args(["sh", test_sh], hidden = [
                    out_dir,
                    ctx.attrs.mise_activate,
                    ctx.attrs.test_cmds,
                ])],
                local_resources = { key: label for key, label in ctx.attrs.test_local_resources.items() },
                required_local_resources = [
                    RequiredTestLocalResource(key, listing=False, execution=True)
                    for key in ctx.attrs.test_local_resources.keys()
                ],
            ),
        )

    if len(ctx.attrs.required_envs) > 0:
        validation_result = ctx.actions.declare_output("validation_result.json")
        validation_sh = ctx.actions.write(
            "validation.sh",
            cmd_args([
                "#!/bin/bash",
                "set -euo pipefail",
                "",
                "# 環境変数の存在をチェックする関数",
                "check_env_var() {",
                '  local var_name="$1"',
                '  local error_msg="$2"',
                '',
                '  if [ -z "${!var_name}" ]; then',
                cmd_args(['    echo "$error_msg"', '>', validation_result.as_output()], delimiter=" "),
                '    exit',
                '  fi',
                '}',
                '',
                [
                    cmd_args([
                        "check_env_var",
                        name,
                        json.encode({
                            "version": 1,
                            "data": {
                                "status": "failure",
                                "message": "エラー: 環境変数 {} が設定されていません。".format(name),
                            },
                        }),
                    ], delimiter=" ", quote="shell")
                    for name in ctx.attrs.required_envs
                ],
                '',
                cmd_args([
                    "echo",
                    cmd_args(
                        json.encode({
                            "version": 1,
                            "data": {
                                "status": "success",
                                "message": "OK",
                            },
                        }),
                        quote="shell",
                    ),
                    '>',
                    validation_result.as_output(),
                ], delimiter=" ")
            ]),
            is_executable = True,
        )
        ctx.actions.run(
            cmd_args(["bash", validation_sh], hidden = [
                validation_result.as_output(),
                ctx.attrs.required_envs,
            ]),
            category = 'mise_workspace_env_check',
            always_print_stderr = True,
        )
        providers.append(
            ValidationInfo(
                validations = [
                    ValidationSpec(
                        name = "mise_workspace_env_check",
                        validation_result = validation_result,
                        optional = False,
                    ),
                ],
            ),
        )

    providers.append(
        DefaultInfo(
            default_output = out_dir,
            sub_targets = sub_targets,
        ),
    )

    return providers

mise_workspace = rule(
    impl = _mise_workspace_impl,
    attrs = {
        "required_envs": attrs.list(attrs.string(), default = []),
        "mise_activate": attrs.string(),
        "srcs": attrs.list(attrs.source(), default = []),
        "build_cmds": attrs.list(attrs.arg(), default = []),
        "sub_targets": attrs.one_of(
            attrs.list(attrs.string()),
            attrs.dict(
                attrs.string(),
                attrs.list(attrs.string()),
            ),
            default = [],
        ),
        "run_cmds": attrs.list(attrs.arg(), default = []),
        "test_cmds": attrs.list(attrs.arg(), default = []),
        "test_local_resources": attrs.dict(key = attrs.string(), value = attrs.label(), sorted = False, default = {}),
    },
)
