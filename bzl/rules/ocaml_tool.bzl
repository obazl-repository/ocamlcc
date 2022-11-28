load("//bzl/actions:executable_impl.bzl", "executable_impl")
load("//bzl/attrs:executable_attrs.bzl", "executable_attrs")
# load("//bzl/rules/common:transitions.bzl", "executable_in_transition")

########################
# def _tool(ctx):

#     tc = ctx.toolchains["//toolchain/type:boot"]
#     return impl_executable(ctx, tc)

#######################
ocaml_tool = rule(
    implementation = executable_impl,

    # exec_groups = {
    #     "boot": exec_group(
    #         # exec_compatible_with = [
    #         #     "//platform/constraints/ocaml/executor:vm_executor?",
    #         #     "//platform/constraints/ocaml/emitter:vm_emitter"
    #         # ],
    #         toolchains = ["//toolchain/type:boot"],
    #     ),
        # "baseline": exec_group(
        #     exec_compatible_with = [
        #         "//platform/constraints/ocaml/executor:vm_executor?",
        #         "//platform/constraints/ocaml/emitter:vm_emitter"
        #     ],
        #     toolchains = ["//toolchain/type:baseline"],
        # ),
     # },

    attrs = dict(
        executable_attrs(),

        _rule = attr.string( default = "ocaml_tool" ),
        # _allowlist_function_transition = attr.label(
        #     default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        # ),
    ),
    # cfg = executable_in_transition,
    executable = True,
    fragments = ["cpp"],
    toolchains = ["//toolchain/type:boot",
                  ## //toolchain/type:profile,",
                  "@bazel_tools//tools/cpp:toolchain_type"]
)
