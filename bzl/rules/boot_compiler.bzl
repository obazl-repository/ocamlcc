## Special rule to build the compiler. Action: link module deps.

## Other basic executables in the tc: ocamllex, ocamlyacc, ocamlopt,
## native versions of each, some internal tools (make_opcodes, etc.).
## Executable targets in `tools/` don't count as core tools, they can
## be built after the compiler tools are built.

load("//bzl:providers.bzl",
     "CompilationModeSettingProvider",
     "BootInfo",
     "ModuleInfo",

     "OcamlArchiveProvider",
     "OcamlExecutableMarker",
     "OcamlImportMarker",
     "OcamlLibraryMarker",
     "OcamlNsResolverProvider",
     "OcamlNsMarker",
     "OcamlSignatureProvider",
     "OcamlTestMarker")

load(":impl_executable.bzl", "impl_executable")

load(":BUILD.bzl", "exe_deps_out_transition")

load(":boot_attrs_executable.bzl", "options_executable")

# load(":options.bzl",
#      "options",
#      "options_executable",
#      "get_options")

################################
####################################################
# def _boot_compiler_in_transition_impl(settings, attr):
#     print("boot_compiler_in_transition")
#     # print("  stage: %s" % settings["//bzl:stage"])
#     # print("//bzl/toolchain:ocamlc: %s" %
#     #       settings["//bzl/toolchain:ocamlc"])

#     return {
#         "//command_line_option:host_platform" : "//platforms/build:boot",
#         "//command_line_option:platforms" : "//platforms/target:boot"
#     }

# boot_compiler_in_transition = transition(
#     implementation = _boot_compiler_in_transition_impl,
#     inputs = [
#         "//command_line_option:host_platform",
#         "//command_line_option:platforms"
#     ],
#     outputs = [
#         "//command_line_option:host_platform",
#         "//command_line_option:platforms"
#     ]
# )

# #####################################################
# def _boot_compiler_out_transition_impl(settings, attr):
#     print("boot_compiler_out_transition")
#     # print("  stage: %s" % settings["//bzl:stage"])

#     # print("//bzl/toolchain:ocamlc: %s" %
#     #       settings["//bzl/toolchain:ocamlc"])

#     return {
#         "//bzl:stage": 1,
#         "//bzl/toolchain:ocamlc" : "//boot:ocamlc"
#     }

# #######################
# boot_compiler_out_transition = transition(
#     implementation = _boot_compiler_out_transition_impl,
#     inputs = [
#         "//bzl:stage",
#         "//bzl/toolchain:ocamlc"
#     ],
#     outputs = [
#         "//bzl:stage",
#         "//bzl/toolchain:ocamlc"
#     ]
# )

################################################################
rule_options = options_executable("ocaml")

########################
boot_compiler = rule(
    implementation = impl_executable,

    doc = "Builds stage 1 ocamlc using stage 0 boot/ocamlc",

    attrs = dict(
        rule_options,

        primitives = attr.label(
            default = "//runtime:primitives", # file produced by genrule
            allow_single_file = True,
            # cfg = boot_compiler_out_transition,
        ),

        # _allowlist_function_transition = attr.label(
        #     default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        # ),

        _rule = attr.string( default = "boot_compiler" ),
    ),
    # cfg = boot_compiler_in_transition,
    executable = True,
    toolchains = ["//toolchain/type:bootstrap"],
)
