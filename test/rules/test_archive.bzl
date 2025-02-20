load("//bzl:providers.bzl", "BootInfo", "OcamlArchiveProvider")

load("//bzl/attrs:archive_attrs.bzl", "archive_attrs")
load("//bzl/actions:archive_impl.bzl", "archive_impl")

#####################
test_archive = rule(
    implementation = archive_impl,
    doc = """Generates an OCaml archive file using the bootstrap toolchain.""",
    attrs = dict(
        archive_attrs(),
        _rule = attr.string( default = "test_archive" ),
    ),
    provides = [OcamlArchiveProvider, BootInfo],
    executable = False,
    # fragments = ["platform", "cpp"],
    # host_fragments = ["platform",  "cpp"],
    incompatible_use_toolchain_transition = True, #FIXME: obsolete?
    toolchains = ["//toolchain/type:ocaml",
                  # ## //toolchain/type:profile,",
                  "@bazel_tools//tools/cpp:toolchain_type"]
)
