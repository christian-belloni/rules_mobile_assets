load("@aspect_bazel_lib//lib:strings.bzl", "hex")
load(":common.bzl", "COMMON_ATTRS", "copy_image")
load(":providers.bzl", "ColorProvider", "ColorResourceProvider", "ImageResourceProvider", "LocalizationProvider", "LocalizationResourceProvider", "SharedAssetProvider")

def _android_assets_impl(ctx):
    resources = ctx.attr.resources[SharedAssetProvider]

    base_path = "%s/res" % ctx.attr.name

    strings = _generate_strings(ctx, resources.strings, base_path)
    colors = _generate_colors(ctx, resources.colors, base_path)
    images = _generate_images(ctx, resources.images, base_path)
    icons = _generate_app_icons(ctx, resources.app_icon, base_path)

    return DefaultInfo(
        files = depset(direct = strings + colors + images + icons),
    )

SIZES = {
    "xxxhdpi": 192,
    "xxhdpi": 144,
    "xhdpi": 96,
    "hdpi": 72,
    "mdpi": 48,
}

def _generate_app_icons(ctx, app_icon, common_directory):
    ret = []
    for f in SIZES:
        ret.append(_generate_size(ctx, app_icon, common_directory, f, SIZES[f]))
    return ret

def _generate_size(ctx, app_icon, common_directory, size_folder, size):
    icon = ctx.actions.declare_file("{}/mipmap-{}/ic_launcher.webp".format(common_directory, size_folder))

    args = ["resize", "--svg", app_icon[DefaultInfo].files.to_list()[0].path, "--size", "%s" % size, "--out", icon.path, "--webp"]

    ctx.actions.run(
        inputs = app_icon.files,
        arguments = args,
        executable = ctx.executable._resizer,
        outputs = [icon],
        mnemonic = "GenerateIcon",
    )

    return icon

def _generate_images(ctx, images, common_directory):
    ret = []
    for image in images:
        values = _generate_image(ctx, image[ImageResourceProvider], common_directory)
        for v in values:
            ret.append(v)
    return ret

def _generate_image(ctx, image, common_directory):
    base_image = image.base_image[DefaultInfo].files.to_list()[0]
    dark_image = base_image
    if image.dark_theme != None:
        dark_image = image.dark_theme[DefaultInfo].files.to_list()[0]

    base_image_name = base_image.basename.split(".")[0]

    base_image_dest = ctx.actions.declare_file("{}/drawable/{}.png".format(common_directory, base_image_name))

    copy_image(ctx = ctx, image = base_image, dest = base_image_dest)

    dark_image_dest = ctx.actions.declare_file("{}/drawable-night/{}.png".format(common_directory, base_image_name))

    copy_image(ctx = ctx, image = dark_image, dest = dark_image_dest)

    return [base_image_dest, dark_image_dest]

def _generate_colors(ctx, colors, common_directory):
    base_out = ctx.actions.declare_file("{}/values/colors.xml".format(common_directory))
    dark_out = ctx.actions.declare_file("{}/values-night/colors.xml".format(common_directory))

    format_base = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<resources>\n"
    format_dark = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<resources>\n"

    for color in colors:
        base, dark = _generate_color(ctx, color[ColorResourceProvider], common_directory)
        format_base += base
        format_dark += dark
    format_base += "</resources>"
    format_dark += "</resources>"

    ctx.actions.write(output = base_out, content = format_base)
    ctx.actions.write(output = dark_out, content = format_dark)

    return [base_out, dark_out]

def _generate_color(ctx, color, common_directory):
    name = color.name
    base = color.base[ColorProvider]
    dark = color.dark[ColorProvider]

    base_format = "<color name=\"{}\">#{}</color>\n".format(name, _rgb_to_hex(base))
    dark_format = "<color name=\"{}\">#{}</color>\n".format(name, _rgb_to_hex(dark))

    return (base_format, dark_format)

def _rgb_to_hex(color):
    return "{}{}{}{}".format(_hex(color.alpha), _hex(color.red), _hex(color.green), _hex(color.blue)).replace("0x", "")

def _hex(val):
    val = hex(val).replace("0x", "")
    if len(val) != 2:
        val = "0" + val
    return val

def _generate_strings(ctx, strings, common_directory):
    strings = strings[LocalizationProvider]
    first = strings.localizations[0]
    first = first[LocalizationResourceProvider]
    langs = first.values.keys()
    files = []
    base_lang = strings.base_language
    for lang in langs:
        files += _acc_lang(ctx, strings, common_directory, lang, lang == base_lang)

    return files

def _acc_lang(ctx, strings, common_directory, lang, is_base_language = False):
    out_files = []
    if is_base_language:
        out_file_base = ctx.actions.declare_file("{}/values/lang.xml".format(common_directory))
        out_file = ctx.actions.declare_file("{}/values-{}/lang.xml".format(common_directory, lang))
        out_files = [out_file_base, out_file]
    else:
        out_files = [ctx.actions.declare_file("{}/values-{}/lang.xml".format(common_directory, lang))]

    format = """<?xml version="1.0" encoding="utf-8"?>\n<resources>\n"""

    for vals in strings.localizations:
        vals = vals[LocalizationResourceProvider]
        val = vals.values[lang]
        key = vals.key
        format += write_entry(key, val)
    format += "\n</resources>"
    for out_file in out_files:
        ctx.actions.write(output = out_file, content = format)

    return out_files

def write_entry(key, val):
    val = val.replace("&", "\\&amp;").replace("<", "\\&lt;").replace(">", "\\&gt;").replace("\"", "\\&quot;").replace("'", "\\&apos;")
    return "<string name=\"{}\">{}</string>\n".format(key, val)

android_assets = rule(
    doc = "Extracts the necessary metadata from shared_assets and produces the required directory structure for android_{binary, library} resource_files",
    implementation = _android_assets_impl,
    attrs = COMMON_ATTRS,
    output_to_genfiles=True
)
