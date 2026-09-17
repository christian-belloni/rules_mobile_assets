load("@rules_rust//rust:defs.bzl", "rust_binary")
load("@rma_crates//:defs.bzl", "all_crate_deps")

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
  deps = all_crate_deps()
)
