//! Preparación de la foto antes de enviarla a cualquier proveedor.
//!
//! - Aplica la orientación EXIF (las fotos del celular suelen venir giradas).
//! - Reduce el lado mayor a [`MAX_SIDE_PX`] y recodifica en JPEG calidad [`JPEG_QUALITY`]. LogMeal pide JPEG de
//!   máximo 1000 px y menos de 1 MB; a los demás les baja el tiempo de subida (RNF-01).
//! - Es de mejor esfuerzo: si la imagen no se puede decodificar, se envía tal cual y el proveedor decide.
//!
//! Decodificar y recodificar usa CPU: llámala dentro de `tokio::task::spawn_blocking`.

use std::io::Cursor;

use image::{DynamicImage, ImageDecoder, ImageReader, codecs::jpeg::JpegEncoder};

use super::FoodImage;
use crate::services::photos;

/// Lado mayor máximo de la imagen enviada.
pub const MAX_SIDE_PX: u32 = 1000;
/// Calidad JPEG de la imagen enviada.
pub const JPEG_QUALITY: u8 = 85;

/// Imagen lista para el proveedor.
pub fn prepare(bytes: Vec<u8>) -> FoodImage {
    match reencode(&bytes) {
        Some(jpeg) => FoodImage {
            bytes: jpeg,
            mime: "image/jpeg",
        },
        None => {
            let mime = photos::detect_format(&bytes)
                .map(|format| format.mime_type())
                .unwrap_or("image/jpeg");
            FoodImage { bytes, mime }
        }
    }
}

fn reencode(bytes: &[u8]) -> Option<Vec<u8>> {
    let mut decoder = ImageReader::new(Cursor::new(bytes))
        .with_guessed_format()
        .ok()?
        .into_decoder()
        .ok()?;
    let orientation = decoder.orientation().ok();
    let mut image = DynamicImage::from_decoder(decoder).ok()?;
    if let Some(orientation) = orientation {
        image.apply_orientation(orientation);
    }
    if image.width().max(image.height()) > MAX_SIDE_PX {
        image = image.resize(
            MAX_SIDE_PX,
            MAX_SIDE_PX,
            image::imageops::FilterType::Triangle,
        );
    }
    let rgb = image.to_rgb8();
    let mut out = Vec::new();
    JpegEncoder::new_with_quality(&mut out, JPEG_QUALITY)
        .encode_image(&rgb)
        .ok()?;
    Some(out)
}

#[cfg(test)]
mod tests {
    use super::*;
    use image::{ImageFormat, RgbImage};

    fn png(width: u32, height: u32) -> Vec<u8> {
        let image = RgbImage::from_fn(width, height, |x, y| {
            image::Rgb([(x % 256) as u8, (y % 256) as u8, 128])
        });
        let mut out = Cursor::new(Vec::new());
        image.write_to(&mut out, ImageFormat::Png).unwrap();
        out.into_inner()
    }

    fn dimensions(bytes: &[u8]) -> (u32, u32) {
        let image = image::load_from_memory(bytes).unwrap();
        (image.width(), image.height())
    }

    #[test]
    fn una_foto_grande_se_reduce_a_1000_px_y_queda_en_jpeg() {
        let prepared = prepare(png(2000, 1500));
        assert_eq!(prepared.mime, "image/jpeg");
        assert!(prepared.bytes.starts_with(&[0xFF, 0xD8, 0xFF]));
        assert_eq!(dimensions(&prepared.bytes), (1000, 750));
    }

    #[test]
    fn una_foto_pequena_conserva_su_tamano() {
        let prepared = prepare(png(640, 480));
        assert_eq!(prepared.mime, "image/jpeg");
        assert_eq!(dimensions(&prepared.bytes), (640, 480));
    }

    #[test]
    fn una_foto_que_no_se_puede_decodificar_se_envia_tal_cual() {
        // Firma JPEG válida (pasa HU-06) pero contenido corrupto.
        let bytes = vec![0xFF, 0xD8, 0xFF, 0x00, 0x01, 0x02];
        let prepared = prepare(bytes.clone());
        assert_eq!(prepared.bytes, bytes);
        assert_eq!(prepared.mime, "image/jpeg");

        let mut corrupt_png = png(10, 10);
        corrupt_png.truncate(20);
        assert_eq!(prepare(corrupt_png).mime, "image/png");
    }
}
