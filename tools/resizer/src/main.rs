use std::{
    fs::File,
    io::{BufWriter, Write},
    path::PathBuf,
};

use clap::{Parser, Subcommand};
use image::{codecs::png::PngEncoder, GenericImageView, ImageEncoder, ImageReader};
use image_webp::WebPEncoder;
use resvg::tiny_skia::PremultipliedColorU8;

fn main() {
    let args = Args::parse();
    match args.command {
        Command::Convert { image, out } => {
            let image = ImageReader::open(&image)
                .unwrap()
                .with_guessed_format()
                .unwrap()
                .decode()
                .unwrap();
            let mut out = BufWriter::new(
                std::fs::OpenOptions::new()
                    .write(true)
                    .truncate(true)
                    .create(true)
                    .open(&out)
                    .unwrap(),
            );
            let encoder = PngEncoder::new(&mut out);

            encoder
                .write_image(
                    image.as_bytes(),
                    image.dimensions().0,
                    image.dimensions().1,
                    image.color().into(),
                )
                .unwrap();
        }
        Command::Resize {
            svg,
            out,
            size,
            webp,
        } => {
            let input = std::fs::canonicalize(&svg).unwrap().to_path_buf();
            let mut opt = resvg::usvg::Options::default();
            opt.resources_dir = input.parent().map(|a| a.to_path_buf());
            opt.fontdb_mut().load_system_fonts();
            let svg_data = std::fs::read(&input).unwrap();
            let svg = resvg::usvg::Tree::from_data(&svg_data, &opt).unwrap();

            let mut pixmap = resvg::tiny_skia::Pixmap::new(size, size).unwrap();
            let current_size = svg.size();

            let transform_x = size as f32 / current_size.width();
            let transform_y = size as f32 / current_size.height();

            resvg::render(
                &svg,
                resvg::tiny_skia::Transform::from_scale(transform_x, transform_y),
                &mut pixmap.as_mut(),
            );

            pixmap.pixels_mut().iter_mut().for_each(|pix| {
                if !pix.is_opaque() {
                    *pix = PremultipliedColorU8::from_rgba(255, 255, 255, 255).unwrap()
                }
            });

            if webp {
                let out = File::create(&out).unwrap();
                let mut out = BufWriter::new(out);
                let encoder = WebPEncoder::new(&mut out);
                encoder
                    .encode(
                        pixmap.data(),
                        pixmap.width(),
                        pixmap.height(),
                        image_webp::ColorType::Rgba8,
                    )
                    .unwrap();
                out.flush().unwrap();
            } else {
                pixmap.save_png(&out).unwrap();
            }
        }
    }
}

#[derive(Debug, clap::Parser)]
struct Args {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand, Debug, Clone)]
enum Command {
    Convert {
        #[clap(long)]
        image: PathBuf,

        #[clap(long)]
        out: PathBuf,
    },
    Resize {
        #[clap(long)]
        /// Input svg
        svg: PathBuf,
        #[clap(long)]
        /// Output path
        out: PathBuf,
        #[clap(long)]
        /// Output size in pixels
        size: u32,

        #[clap(long, default_value = "false")]
        webp: bool,
    },
}
