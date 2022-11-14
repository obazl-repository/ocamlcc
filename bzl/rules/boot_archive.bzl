load("//bzl:providers.bzl", "BootInfo", "OcamlArchiveProvider")

load("//bzl/attrs:archive_attrs.bzl", "archive_attrs")
load("//bzl/actions:archive_impl.bzl", "archive_impl")

#####################
boot_archive = rule(
    implementation = archive_impl,
    doc = """Generates an OCaml archive file using the bootstrap toolchain.""",
    exec_groups = {
        "boot": exec_group(
            exec_compatible_with = [
                "//platform/constraints/ocaml/executor:vm?",
                "//platform/constraints/ocaml/emitter:vm"
            ],
            toolchains = ["//boot/toolchain/type:boot"],
        ),
        # "baseline": exec_group(
        #     exec_compatible_with = [
        #         "//platform/constraints/ocaml/executor:vm?",
        #         "//platform/constraints/ocaml/emitter:vm"
        #     ],
        #     toolchains = ["//boot/toolchain/type:baseline"],
        # ),
    },

    attrs = dict(
        archive_attrs(),
        _rule = attr.string( default = "boot_archive" ),
    ),
    provides = [OcamlArchiveProvider, BootInfo],
    executable = False,
    # fragments = ["platform", "cpp"],
    # host_fragments = ["platform",  "cpp"],
    incompatible_use_toolchain_transition = True, #FIXME: obsolete?
    # toolchains = ["//toolchain/type:boot",
    #               # "//toolchain/type:profile",
    #               "@bazel_tools//tools/cpp:toolchain_type"]
)
