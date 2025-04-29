def _aws_codeartifact_get_authorization_token_impl(ctx: AnalysisContext) -> list[Provider]:
    token_out = ctx.actions.declare_output('token.txt')
    setup_sh = ctx.actions.write(
        "setup.sh",
        cmd_args([
            "#!/bin/sh",
            "set -e",
            "set -o pipefail",
            "",
            cmd_args([
                'aws', 'codeartifact', 'get-authorization-token',
                '--domain', ctx.attrs.domain,
                '--domain-owner', ctx.attrs.domain_owner,
                '--query', 'authorizationToken',
                '--output', 'text',
                '--profile', ctx.attrs.profile,
                '>', token_out.as_output(),
            ], delimiter=" "),
        ]),
        is_executable = True,
    )
    ctx.actions.run(
        cmd_args(
            ["sh", setup_sh],
            hidden = [
                token_out.as_output(),
                ctx.attrs.domain,
                ctx.attrs.domain_owner,
                ctx.attrs.profile,
            ],
        ),
        category = 'setup',
        always_print_stderr = True,
    )

    json_out = ctx.actions.declare_output('token.json')
    def f(dynamic_ctx, artifacts, outputs):
        token = artifacts[token_out].read_string()
        dynamic_ctx.actions.write_json(
            outputs[json_out],
            {
                "resources": [
                    {
                        "token": token,
                    },
                ],
            },
        )

    ctx.actions.dynamic_output(
        dynamic = [token_out],
        inputs = [],
        outputs = [json_out.as_output()],
        f = f,
    )

    return [
        DefaultInfo(),
        LocalResourceInfo(
            setup = cmd_args(["cat", json_out]),
            resource_env_vars = {
                "MY_RESOURCE_ID": "token",
            },
            setup_timeout_seconds = 5,
        ),
    ]

aws_codeartifact_get_authorization_token = rule(
    impl = _aws_codeartifact_get_authorization_token_impl,
    attrs = {
        "domain": attrs.string(),
        "domain_owner": attrs.string(),
        "profile": attrs.string(),
    },
)

def _xxx_impl(ctx):
    return [DefaultInfo(), ExternalRunnerTestInfo(
        type = "custom",
        command = ["env"],
        local_resources = {
            "my_resource_type": ctx.attrs.broker.label,
        },
        required_local_resources = [
            RequiredTestLocalResource("my_resource_type"),
        ],
    )]

xxx = rule(
    impl = _xxx_impl,
    attrs = {
        "broker": attrs.dep(providers = [LocalResourceInfo]),
    },
)
