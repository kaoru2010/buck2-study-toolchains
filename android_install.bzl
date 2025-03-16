def _android_install_impl(ctx: AnalysisContext) -> list[Provider]:
    resources = { src.short_path: src for src in [ctx.attrs.apk_path] }
    resources_dir = ctx.actions.copied_dir("resources", resources)

    run_sh = ctx.actions.declare_output('run.sh')

    def f(ctx: AnalysisContext, artifacts, outputs):
        json = artifacts[ctx.attrs.metadata_path].read_json()
        applicationId = json["applicationId"]
        ctx.actions.write(
            outputs[run_sh],
            cmd_args([
                "#!/bin/sh",
                "set -e",
                "set -o pipefail",
                "",
                '__SRC="${BASH_SOURCE[0]}"',
                '__SRC="$(realpath "$__SRC")"',
                '__SCRIPT_DIR=$(dirname "$__SRC")',
                cmd_args(resources_dir, format = "export BUCK_PROJECT_ROOT=\"$__SCRIPT_DIR/{}\"", relative_to=(outputs[run_sh], 1)),
                "",
                '# ADBで上書きインストール（-rオプションでデータ保持）',
                'adb install -r $BUCK_PROJECT_ROOT/' + ctx.attrs.apk_path.short_path,
                "",
                cmd_args(applicationId, format='echo "Detected package name: {}"'),
                '',
                '# アプリを起動',
                cmd_args(applicationId, format='adb shell monkey -p {} -c android.intent.category.LAUNCHER 1'),
            ]),
            is_executable = True,
        )
    ctx.actions.dynamic_output(dynamic = [ctx.attrs.metadata_path], inputs = [], outputs = [run_sh.as_output()], f = f)

    return [
        DefaultInfo(default_output = run_sh),
        RunInfo(
            args = cmd_args(run_sh, hidden = [ctx.attrs.apk_path, ctx.attrs.metadata_path, resources_dir]),
        ),
    ]

android_install = rule(
    impl = _android_install_impl,
    attrs = {
        "apk_path": attrs.source(),
        "metadata_path": attrs.source(),
    }
)
