load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load(":BUILD.bzl", "progress_msg")
#, "get_build_executor", "configure_action")

load("//bzl:providers.bzl",
     "BootInfo",
     "ModuleInfo",
     "SigInfo",
     "StdlibSigMarker",
     "StdSigMarker",
     "new_deps_aggregator",
     "OcamlSignatureProvider")

load("//bzl:functions.bzl", "get_module_name")

load("//bzl/rules/common:options.bzl", "get_options")

load("//bzl/rules/common:impl_common.bzl", "dsorder")

load("//bzl/rules/common:DEPS.bzl", "aggregate_deps", "merge_depsets")

########################
def signature_impl(ctx, module_name):

    debug = False
    debug_bootstrap = False

    basename = ctx.label.name
    from_name = basename[:1].capitalize() + basename[1:]

    tc = ctx.toolchains["//toolchain/type:ocaml"]
    # print("SIG n: %s" % ctx.label.name)
    # print("SIG tc.name: %s" % tc.name)

    workdir = tc.workdir

    #########################
    args = ctx.actions.args()

    toolarg = tc.tool_arg
    # if ctx.label.name == "CamlinternalFormatBasics_cmi":
    #     print("SIG tool_arg: %s" % toolarg)
    if toolarg:
        args.add(toolarg.path)
        toolarg_input = [toolarg]
    else:
        toolarg_input = []

    ################
    includes   = []

    sig_src = ctx.file.src
    # sig_ext = ctx.file.src.extension
    if debug:
        print("sig_src: %s" % sig_src)

    # add prefix if namespaced. from_name == normalized module name
    # derived from sig_src; module_name == prefixed if ns else same as
    # from_name.

    ns = None
    if debug:
        print("Module name: {src} To: {dst}".format(
            src = from_name, dst = module_name))

    if from_name == module_name:
        ## We need to ensure mli file and cmi file are in the same
        ## place. Since Bazel writes output files into its own dirs
        ## (won't write back into src dir), this means we need to
        ## symlink the source mli file into the same output directory,
        ## so that it will be found when it comes time to compile the
        ## .ml file.

        if debug:
            print("not namespaced")
        if sig_src.is_source:  # i.e. not generated by a preprocessor
            mlifile = ctx.actions.declare_file(workdir + module_name + ".mli") # sig_src.basename)
            ctx.actions.symlink(output = mlifile,
                                target_file = sig_src)
            if debug:
                print("symlinked {src} => {dst}".format(
                    src = sig_src.path, dst = mlifile.path))
        else:
            ## generated file, already in bazel dir
            if debug:
                print("not symlinking {src}".format(
                    src = sig_src))

            mlifile = sig_src

    else:
        # namespaced w/o ppx: symlink sig_src to prefixed name, so
        # that output dir will contain both renamed input mli and
        # output cmi.
        ns_sig_src = module_name + ".mli"
        if debug:
            print("ns_sig_src: %s" % ns_sig_src)
        mlifile = ctx.actions.declare_file(workdir + ns_sig_src)
        ctx.actions.symlink(output = mlifile,
                            target_file = sig_src)
        if debug:
            print("symlinked {src} => {dst}".format(
                src = sig_src.path, dst = mlifile.path))

    direct_inputs = [mlifile]

    # if sig_src.extension == "ml":  ## wtf?
    #     ofile = workdir + sig_src.basename + "i"
    #     out_cmi = ctx.actions.declare_file(ofile)
    # else:
    ocmi = workdir + module_name + ".cmi"
    # if ctx.label.name == "CamlinternalFormatBasics_cmi":
    #     print("OCMI: %s" % ocmi)

    action_outputs = []
    out_cmi = ctx.actions.declare_file(ocmi)
    action_outputs.append(out_cmi)

    (_options, cancel_opts) = get_options(ctx.attr._rule, ctx)

    if "-pervasives" in _options:
        cancel_opts.append("-nopervasives")
        _options.remove("-pervasives")
    # else:
    #     _options.append("-nopervasives")

    out_cmti = None
    if ( ("-bin-annot" in _options)
         or ("-bin-annot" in tc.copts) ):
        out_cmti = ctx.actions.declare_file(workdir + module_name + ".cmti")
        action_outputs.append(out_cmti)
        # default_outputs.append(out_cmt)

    if debug:
        print("out_cmi %s" % out_cmi)


    ################################################################
    ################  DEPS  ################
    depsets = new_deps_aggregator()

    manifest = []

    open_stdlib = False
    no_alias_deps = False
    stdlib_module_target  = None
    stdlib_primitives_target  = None
    stdlib_library_target = None

    for dep in ctx.attr.deps:
        depsets = aggregate_deps(ctx, dep, depsets, manifest)

    if hasattr(ctx.attr, "struct_deps"):
        for dep in ctx.attr.struct_deps:
            depsets = aggregate_deps(ctx, dep, depsets, manifest)
        # if len(ctx.attr.stdlib_deps) < 1:
        # if dep.label.package == "stdlib":
        #     if dep.label.name in ["Primitives", "Stdlib"]:
        #         open_stdlib = True
        #         stdlib_module_target = dep
        #     # elif dep.label.name == "Stdlib":
        #     #     open_stdlib = True
        #     elif dep.label.name.startswith("Stdlib"): ## stdlib submodule
        #         open_stdlib = True
        #     elif dep.label.name == "stdlib": ## stdlib archive OR library
        #         open_stdlib = True
        #         stdlib_library_target = dep

    if hasattr(ctx.attr, "stdlib_deps"):
        if len(ctx.attr.stdlib_deps) > 0:
            no_alias_deps = True
            if not ctx.label.name == "Stdlib_cmi":
                open_stdlib = True
        for dep in ctx.attr.stdlib_deps:
            depsets = aggregate_deps(ctx, dep, depsets, manifest)
            if dep.label.name == "Primitives":
                stdlib_primitives_target = dep
            elif dep.label.name == "Stdlib":  ## Stdlib resolver
                stdlib_module_target = dep
            elif dep.label.name.startswith("Stdlib"): ## stdlib submodule
                stdlib_module_target = dep
            elif dep.label.name == "stdlib": ## stdlib archive OR library
                stdlib_library_target = dep
                break;

    if hasattr(ctx.attr, "ns"):
        if ctx.attr.ns:
            # for dep in ctx.attr.ns:
            depsets = aggregate_deps(ctx, ctx.attr.ns, depsets, manifest)

    ## build depsets here, use for OcamlProvider and OutputGroupInfo
    sigs_depset = depset(
        order=dsorder,
        direct = [out_cmi],
        transitive = [merge_depsets(depsets, "sigs")])

    cli_link_deps_depset = depset(
        order = dsorder,
        transitive = [merge_depsets(depsets, "cli_link_deps")]
    )

    afiles_depset  = depset(
        order=dsorder,
        transitive = [merge_depsets(depsets, "afiles")]
    )

    ofiles_depset  = depset(
        order=dsorder,
        transitive = [merge_depsets(depsets, "ofiles")]
    )

    archived_cmx_depset = depset(
        order=dsorder,
        transitive = [merge_depsets(depsets, "archived_cmx")]
    )

    paths_depset  = depset(
        order = dsorder,
        direct = [out_cmi.dirname],
        transitive = [merge_depsets(depsets, "paths")]
    )

    # if ctx.label.name == "CamlinternalFormatBasics_cmi":
    #     print("depsets: %s" % depsets)
    #     fail("x")

    if debug:
        print("tgt: %s" % ctx.label)
        print("tc.executable: %s" % tc.executable)
        print("tc.tool_arg: %s" % tc.tool_arg)
        print("tc.protocol: %s" % tc.protocol)

    resolver = []
    if hasattr(ctx.attr, "ns"):
        if ctx.attr.ns:
            resolver.append(ctx.attr.ns[ModuleInfo].sig)
            resolver.append(ctx.attr.ns[ModuleInfo].struct)
            ns = ctx.attr.ns[ModuleInfo].struct.basename[:-4]
            args.add_all(["-open", ns])

    if hasattr(ctx.attr, "_opts"):
        args.add_all(ctx.attr._opts)

    tc_opts = []
    if not ctx.attr.nocopts:
        # for opt in tc.copts:
        #     if opt not in NEGATION_OPTS:
        #         args.add(opt)
        #     else:
        # args.add_all(tc.copts)
        tc_opts.extend(tc.copts)

    # args.add_all(tc.structopts)
    tc_opts.extend(tc.structopts)

    for opt in tc_opts:
        if opt not in cancel_opts:
            args.add(opt)

    args.add_all(tc.warnings[BuildSettingInfo].value)

    for w in ctx.attr.warnings:
        args.add_all(["-w",
                      w if w.startswith("-")
                      else "-" + w])

    args.add_all(_options)

    if no_alias_deps:
        args.add("-no-alias-deps") ##FIXME: control this w/flag?
    if open_stdlib:
        args.add("-open", "Stdlib")

    if hasattr(ctx.attr, "ns"):
        if ctx.attr.ns:
            # includes.append(ctx.attr.ns[ModuleInfo].sig.dirname)
            includes.append(ctx.attr.ns[ModuleInfo].sig.dirname)
            direct_inputs.append(ctx.attr.ns[ModuleInfo].sig)
            direct_inputs.append(ctx.attr.ns[ModuleInfo].struct)


    # if hasattr(ctx.attr, "stdlib_primitives"): # test rules
    #     if ctx.attr.stdlib_primitives:
    #         includes.append(ctx.attr._stdlib[ModuleInfo].sig.dirname)
    #         direct_inputs.append(ctx.attr._stdlib[ModuleInfo].sig)
    #         direct_inputs.append(ctx.attr._stdlib[ModuleInfo].struct)

    ccInfo_list = []

    includes.extend(paths_depset.to_list())

    args.add_all(includes, before_each="-I", uniquify = True)

    # args.add("-I", mlifile.dirname)

    if sig_src.extension == "ml":
        args.add("-i")
    else:
        args.add("-c")

    pack_ns = False
    if hasattr(ctx.attr, "_pack_ns"):
        if ctx.attr._pack_ns:
            if ctx.attr._pack_ns[BuildSettingInfo].value:
                pack_ns = ctx.attr._pack_ns[BuildSettingInfo].value
                # print("GOT PACK NS: %s" % pack_ns)
    if pack_ns:
        args.add("-for-pack", pack_ns)

    args.add("-intf", mlifile)

    args.add("-o", out_cmi)

    if ctx.files.data:
        direct_inputs.extend(ctx.files.data)

    inputs_depset = depset(
        order = dsorder,
        direct = []
        + direct_inputs # + ctx.files._ns_resolver,
        # + [tc.compiler[DefaultInfo].files_to_run.executable],
        # + ctx.files.data if ctx.files.data else [],
        # + [effective_compiler]
        + toolarg_input
        + resolver
        ,
        transitive = []## indirect_inputs_depsets
        + [merge_depsets(depsets, "sigs"),
           merge_depsets(depsets, "cli_link_deps")
           ]
        # + depsets.deps.structs
        # + depsets.deps.sigs
        # + depsets.deps.archives
        # + ns_resolver_depset
        # + [tc.compiler[DefaultInfo].default_runfiles.files]
    )

    ##########################################
    sigexe = tc.executable
    # if ctx.label.name == "CamlinternalFormatBasics_cmi":
    #     print("SIGtc.name: %s" % tc.name)
    #     print("SIGexe: %s" % sigexe)
    ################  ACTION  ################
    ctx.actions.run(
        executable = sigexe,
        arguments = [args],
        inputs = inputs_depset,
        outputs = action_outputs,
        tools = [
        ],
        mnemonic = "CompileOcamlSignature",
        progress_message = progress_msg(workdir, ctx)
    )

    #############################################
    ################  PROVIDERS  ################

    default_depset = depset(
        order = dsorder, direct = [out_cmi]
    )

    defaultInfo = DefaultInfo(
        files = default_depset
    )

    ## FIXME: switch to SigInfo provider
    sigProvider = OcamlSignatureProvider(
        mli  = mlifile,
        cmi  = out_cmi,
        cmti = out_cmti
    )

    sigInfo = SigInfo(
        mli  = mlifile,
        cmi  = out_cmi,
        cmti = out_cmti
    )

    bootInfo = BootInfo(
        sigs     = sigs_depset,
        cli_link_deps = cli_link_deps_depset,
        afiles   = afiles_depset,
        ofiles   = ofiles_depset,
        archived_cmx  = archived_cmx_depset,
        paths    = paths_depset,
    )

    providers = [
        defaultInfo,
        bootInfo,
        sigProvider,
        sigInfo,
    ]

    if ctx.attr._rule in [
        "kernel_signature",
        "stdlib_signature",
        "stdlib_internal_signature"
    ]:
        providers.append(StdlibSigMarker())

    if ctx.attr._rule in [
        "compiler_signature",
        "ns_signature"
    ]:
        providers.append(StdSigMarker())

    if ccInfo_list:
        providers.append(
            cc_common.merge_cc_infos(cc_infos = ccInfo_list)
        )

    outputGroupInfo = OutputGroupInfo(
        sigfile = depset(direct=[mlifile]),
        cmi     = depset(direct=[out_cmi]),
        cmti    = depset(direct=[out_cmti]) if out_cmti else depset(),
        all     = depset(direct=[mlifile, out_cmi]
                         + ([out_cmti] if out_cmti else []))
    )
    providers.append(outputGroupInfo)

    return providers
