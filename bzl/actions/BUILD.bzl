load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

def get_workdir(ctx, tc):
    # build_emitter = tc.build_emitter[BuildSettingInfo].value
    target_executor = tc.target_executor[BuildSettingInfo].value
    target_emitter  = tc.target_emitter[BuildSettingInfo].value
    config_executor = tc.config_executor[BuildSettingInfo].value
    config_emitter  = tc.config_emitter[BuildSettingInfo].value

    debug = False

    if debug:
        print("get_workdir %s" % ctx.label)
        print("target_executor: %s" % target_executor)
        print("target_emitter: %s" % target_emitter)
        print("config_executor: %s" % config_executor)
        print("config_emitter: %s" % config_emitter)

    if tc.dev:
        pfx = "_dev"
    else:
        pfx = ""

    if (config_executor == "boot"):
        workdir = "_boot/"
    elif (config_executor == "baseline"):
        workdir = "_boot/"
    elif (config_executor == "vm" and config_emitter == "boot"):
        if tc.dev:
            # dev mode, passing only --//config/target/executor=vm
            workdir = "_ocamlc.opt/"
        else:
            workdir = "_ocamlc.byte/"
    elif (config_executor == "vm" and config_emitter == "vm"):
        workdir = "_ocamlc.byte/"
    elif (config_executor == "vm" and config_emitter == "sys"):
        if tc.dev:
            workdir = "_ocamlopt.byte/"
        else:
            workdir = "_ocamlopt.byte/"
    elif (config_executor == "sys" and config_emitter == "boot"):
        if tc.dev:
            # dev mode, passing only --//config/target/executor=sys
            workdir = "_ocamlopt.opt/"
        else:
            workdir = "_ocamlc.opt/"
    elif (config_executor == "sys" and config_emitter == "vm"):
        workdir = "_ocamlc.opt/"
    elif (config_executor == "sys" and config_emitter == "sys"):
        workdir = "_ocamlopt.opt/"
    elif config_executor == "unspecified":
        # last stage
        if (config_executor == "boot"):
            workdir = "_boot/"
        if (config_executor == "vm" and config_emitter == "vm"):
            workdir = "_ocamlc.byte/"
        elif (config_executor == "vm" and config_emitter == "sys"):
            workdir = "_ocamlopt.byte/"
        elif (config_executor == "sys" and config_emitter == "sys"):
            workdir = "_ocamlopt.opt/"
        elif (config_executor == "sys" and config_emitter == "vm"):
            workdir = "_ocamlc.opt/"

    if debug:
        print("inferred workdir: %s" % pfx + workdir)

    return (target_executor, target_emitter,
            config_executor, config_emitter,
            pfx + workdir)

###########################
def get_build_executor(tc):

    debug = True
    if debug:
        print("get_build_executor")

    target_executor = tc.target_executor[BuildSettingInfo].value
    target_emitter  = tc.target_emitter[BuildSettingInfo].value
    config_executor = tc.config_executor[BuildSettingInfo].value
    config_emitter  = tc.config_emitter[BuildSettingInfo].value

    if debug:
        print("target_executor %s" % target_executor)
        print("target_emitter  %s" % target_emitter)
        print("config_executor %s" % config_executor)
        print("config_emitter  %s" % config_emitter)

    if tc.dev:
        build_executor = "opt"
    elif (target_executor == "unspecified"):
        if (config_executor == "sys"):
            if config_emitter == "sys":
                # ss built from ocamlopt.byte
                build_executor = "vm"
            else:
                # sv built from ocamlopt.opt
                build_executor = "sys"
        else:
            build_executor = "vm"
    elif (config_executor == "boot" and config_emitter == "boot"):
        build_executor = "vm"
    elif (config_executor == "baseline" and config_emitter == "baseline"):
        build_executor = "vm"
    elif (config_executor == "vm" and config_emitter == "vm"):
        build_executor = "vm"
    elif (config_executor == "vm" and config_emitter == "sys"):
        build_executor = "vm"
    elif (config_executor == "sys" and config_emitter == "sys"):
        ## ss always built by vs (ocamlopt.byte)
        build_executor = "vm"
    elif (config_executor == "sys" and config_emitter == "vm"):
        ## sv built by ss
        build_executor = "sys"

    return build_executor

##############################
## what we need from the config:
# for all targets:
#   * tool to run - ocamlrun + tool, or just tool
#   # tool == either ocamlcc or ocamllex?
# for modules, archives, sigs:
#   * type of output: .cmo/.cmx, .cma/.cmxa, .cmi
# for executables: target executor, to control:
#   * selection of runtime (libcamlrun/libasmrun)
#   * inclusion of camlheaders

# def configure_action(ctx, tc):
#     executable = None
#     if tc.dev:
#         ocamlrun = None
#         effective_compiler = tc.compiler
#     else:
#         ## tc.compiler runfiles: bottom element is always ocamlrun
#         ocamlrun = tc_compiler(tc)[DefaultInfo].default_runfiles.files.to_list()[0]
#         ## most recently built compiler:
#         effective_compiler = tc_compiler(tc)[DefaultInfo].files_to_run.executable

#     build_executor = get_build_executor(tc)
#     # print("xBX: %s" % build_executor)
#     # print("xTX: %s" % config_executor)
#     # print("xef: %s" % effective_compiler)

#     if build_executor == "vm":
#         executable = ocamlrun
#         args.add(effective_compiler.path)
#         if config_executor in ["sys"]:
#             ext = ".cmx"
#         else:
#             ext = ".cmo"
#     else:
#         executable = effective_compiler
#         ext = ".cmx"

#     return (ocamlrun, executable,
#             build_executor, target_executor)

###############################
def progress_msg(workdir, ctx):
    rule = ctx.attr._rule
    if rule in ["ocaml_compiler", "build_tool", "ocaml_lex",
                "ocaml_tool_vm", "ocaml_tool_sys",
                "test_executable"]:
        action = "Linking"
    elif rule in ["compiler_module", "build_module", "stdlib_module", "stdlib_internal_module", "kernel_module", "test_module", "tool_module", "ns_module"]:
        action = "Compiling"
    elif rule in ["compiler_signature", "stdlib_signature", "stdlib_internal_signature", "kernel_signature", "test_signature", "tool_signature", "ns_signature"]:
        action = "Compiling"
    elif rule in ["boot_archive", "test_archive"]:
        action = "Archiving"
    elif rule in ["ocaml_test", "expect_test", "lambda_expect_test",
                  "compile_fail_test"]:
        action = "Testing"
    elif rule in ["lex"]:
        action = "Lexing"
    else:
        fail(rule)

    msg = "{m} [{wd}]: {ws}//{pkg}:{tgt} {action} {rule}".format(
        m   = ctx.var["COMPILATION_MODE"],
        wd  = workdir,
        # m  = ctx.attr._compilation_mode,
        rule= rule,
        ws  = ctx.label.workspace_name if ctx.label.workspace_name else "", ## ctx.workspace_name,
        pkg = ctx.label.package,
        tgt=ctx.label.name,
        action = action
    )
    return msg
