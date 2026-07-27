load("@rules_rust//rust:defs.bzl", "rust_binary")

exports_files(srcs = [
    "Cargo.lock",
    "Cargo.toml",
])

#
rust_binary(
  name = "resizer",
  srcs = glob(["**/*.rs"]),
  edition = "2021",
  visibility = ["//visibility:public"],
  deps = [
    "//3rdparty/crates:clap",
    "//3rdparty/crates:image-webp",
    "//3rdparty/crates:resvg",
    "//3rdparty/crates:image",
  ],
)
