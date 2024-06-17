load("@apple_rules_lint//lint:defs.bzl", "LinterInfo")
load("@bazel_skylib//lib:paths.bzl", "paths")
load(":checkstyle_config.bzl", "CheckStyleInfo")

"""
Checkstyle rule implementation
"""

def _checkstyle_impl(ctx):
    info = ctx.attr.config[CheckStyleInfo]
    name = str(ctx.label)
    config = info.config_file
    output_format = info.output_format

    config_dir = paths.dirname(config.short_path)
    maybe_cd_config_dir = ["cd {}".format(config_dir)] if config_dir else []

    script = "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -o pipefail",
            "set +e",
            "status=0",
            "OLDPWD=$PWD",
        ] + maybe_cd_config_dir + [
            "$OLDPWD/{lib} -o output.txt -f {output_format} -c {config} {srcs} |sed s:$OLDPWD/::g || status=$?".format(
                lib = info.checkstyle.short_path,
                output_format = output_format,
                config = config.basename,
                srcs = " ".join(["$OLDPWD/" + f.short_path for f in ctx.files.srcs]),
            ),
            "cat <<EOF > test.xml",
            '''
<?xml version="1.0" encoding="UTF-8"?>
<testsuite tests="325" failures="30799">
<testcase classname="/Users/fzakaria/code/github.com/confluentinc/ce-kafka/./ce-broker-plugins/src/test/resources/log4j.properties" name="/Users/fzakaria/code/github.com/confluentinc/ce-kafka/./ce-broker-plugins/src/test/resources/log4j.properties">
</testcase>
<testcase classname="/Users/fzakaria/code/github.com/confluentinc/ce-kafka/./ce-broker-plugins/src/test/java/io/confluent/security/auth/oauth/mockserver/MockOAuthTests.java" name="/Users/fzakaria/code/github.com/confluentinc/ce-kafka/./ce-broker-plugins/src/test/java/io/confluent/security/auth/oauth/mockserver/MockOAuthTests.java">
<failure type="com.puppycrawl.tools.checkstyle.checks.javadoc.JavadocPackageCheck">Line 1: Missing package-info.java file. See https://www.shellcheck.net/wiki/awl.tools.checkstyle.checks.javadoc.JavadocPackageCheck</failure>
<failure type="com.puppycrawl.tools.checkstyle.checks.sizes.LineLengthCheck">Line 30: Line is longer than 80 characters (found 84). See https://www.shellcheck.net/wiki/awl.tools.checkstyle.checks.sizes.LineLengthCheck</failure>
<failure type="com.puppycrawl.tools.checkstyle.checks.javadoc.JavadocVariableCheck">Line 30: Missing a Javadoc comment. See https://www.shellcheck.net/wiki/awl.tools.checkstyle.checks.javadoc.JavadocVariableCheck</failure>
<failure type="com.puppycrawl.tools.checkstyle.checks.naming.ConstantNameCheck">Line 30: Name 'log' must match pattern '^[A-Z][A-Z0-9]*(_[A-Z0-9]+)*$'. See https://www.shellcheck.net/wiki/awl.tools.checkstyle.checks.naming.ConstantNameCheck</failure>
<failure type="com.puppycrawl.tools.checkstyle.checks.javadoc.JavadocVariableCheck">Line 32: Missing a Javadoc comment. See https://www.shellcheck.net/wiki/awl.tools.checkstyle.checks.javadoc.JavadocVariableCheck</failure>
<failure type="com.puppycrawl.tools.checkstyle.checks.FinalParametersCheck">Line 230: Parameter resourceType should be final. See https://www.shellcheck.net/wiki/awl.tools.checkstyle.checks.FinalParametersCheck</failure>
</testcase>
</testsuite>
EOF
''',

            #            "<?xml version='1.0' encoding='UTF-8'?>",
            #            "<testsuites>",
            #            "<testsuite name='" + name + "' tests='1' failures='0' errors='1'>",
            #            "<testcase name='" + name + "'>",
            #            "<error message=''>",
            #            "<![CDATA[" + "$(cat output.txt)" + "]]>",
            #            "</error>",
            #            "</testcase>",
            #            "</testsuite>",
            #            "</testsuites>",
            #            "EOF",
            "if [ $status -ne 0 ]; then",
            "  mv test.xml $XML_OUTPUT_FILE",
            "fi",
            "exit $status",
        ],
    )
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
