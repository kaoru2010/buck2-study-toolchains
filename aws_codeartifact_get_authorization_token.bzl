def _aws_codeartifact_get_authorization_token_impl(ctx: AnalysisContext) -> list[Provider]:
    return [
        DefaultInfo(),
        LocalResourceInfo(
            setup = cmd_args([
                ctx.attrs._aws_get_token[RunInfo],
                cmd_args(ctx.attrs.domain, format="--domain={}"),
                cmd_args(ctx.attrs.domain_owner, format="--domain-owner={}"),
                cmd_args(ctx.attrs.profile, format="--profile={}"),
            ]),
            resource_env_vars = {
                "AWS_TOKEN": "token",
            },
            setup_timeout_seconds = 10,
        ),
    ]

aws_codeartifact_get_authorization_token = rule(
    impl = _aws_codeartifact_get_authorization_token_impl,
    attrs = {
        "domain": attrs.string(),
        "domain_owner": attrs.string(),
        "profile": attrs.string(),
        "_aws_get_token": attrs.default_only(attrs.dep(default = "@buck2_study_toolchains//:aws_get_token")),
    },
)
