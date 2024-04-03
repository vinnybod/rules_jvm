load("@apple_rules_lint//lint:defs.bzl", "LinterInfo")
load("@bazel_skylib//lib:paths.bzl", "paths")
load(":checkstyle_config.bzl", "CheckStyleInfo")

"""
Checkstyle rule implementation
"""

def _checkstyle_impl(ctx):
    info = ctx.attr.config[CheckStyleInfo]
    config = info.config_file
    output_format = info.output_format

    config_dir = paths.dirname(config.short_path)
    maybe_cd_config_dir = ["cd {}".format(config_dir)] if config_dir else []

    script = "\n".join([
        "#!/usr/bin/env bash",
        "set -o pipefail",
        "set +e",
        "OLDPWD=$PWD",
        #        "export XML_OUTPUT_FILE=$TEST_UNDECLARED_OUTPUTS_DIR/test.xml",
    ] + maybe_cd_config_dir + [
        "$OLDPWD/{lib} -f {output_format} -c {config} {srcs} |sed s:$OLDPWD/::g > tmpfile".format(
            lib = info.checkstyle.short_path,
            output_format = output_format,
            config = config.basename,
            srcs = " ".join(["$OLDPWD/" + f.short_path for f in ctx.files.srcs]),
        ),
        "cat <<EOF > test.xml",
        "<?xml version='1.0' encoding='UTF-8'?>",
        "<testsuites>",
        "<testsuite name='$TEST_TARGET' tests='1' failures='0' errors='1' time='0'>",
        "<testcase name='$TEST_TARGET' classname='checkstyle' time='0'>",
        "<error message='exited with error code 1'></error>",
        "<system-err>",
        "<![CDATA[",
        "$(cat tmpfile)",
        "]]>",
        "</system-err>",
        "</testcase>",
        "</testsuite>",
        "</testsuites>",
        "EOF",
        "mv test.xml $XML_OUTPUT_FILE",

        # Exit with 1 if there are any errors
        "if grep -q '<error' tmpfile; then",
        "  exit 1",
        "fi",
    ])
    out = ctx.actions.declare_file(ctx.label.name + "exec")

    ctx.actions.write(
        output = out,
        content = ctx.expand_location(script),
    )

    runfiles = ctx.runfiles(
        files = ctx.files.srcs + [info.checkstyle],
    )

    return [
        DefaultInfo(
            executable = out,
            runfiles = runfiles.merge(
                ctx.attr.config[DefaultInfo].default_runfiles,
            ),
        ),
        LinterInfo(
            language = "java",
            name = "checkstyle",
        ),
    ]

_checkstyle_test = rule(
    _checkstyle_impl,
    attrs = {
        "srcs": attr.label_list(
            mandatory = True,
            allow_files = True,
        ),
        "config": attr.label(
            default = "@contrib_rules_jvm//java:checkstyle-default-config",
            providers = [
                [CheckStyleInfo],
            ],
        ),
        "output_format": attr.string(
            doc = "Output Format can be plain or xml. Defaults to plain",
            values = ["plain", "xml"],
            default = "plain",
        ),
    },
    executable = True,
    test = True,
    doc = """Use checkstyle to lint the `srcs`.""",
)

def checkstyle_test(name, size = "medium", timeout = "short", **kwargs):
    _checkstyle_test(
        name = name,
        size = size,
        timeout = timeout,
        **kwargs
    )
