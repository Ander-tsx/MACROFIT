//! TEC-13 — almacenamiento de fotos de comidas en GridFS (bucket `meal_photos`).
//!
//! - Solo JPEG y PNG, detectados por los primeros bytes del archivo (la extensión y el tipo que declara el cliente
//!   no cuentan). Tamaño máximo: [`MAX_PHOTO_BYTES`].
//! - Una foto la leen su dueño y el coach con vinculación activa (RN-04, RNF-05). Para cualquier otra cuenta la foto
//!   "no existe" (`PHOTO_NOT_FOUND`), igual que un id inexistente: no se revela que la foto está ahí.
//! - Solo el dueño la elimina; se borran el documento de `meal_photos.files` y todos sus trozos.
//! - HU-06 sube la foto con [`upload_photo`] (POST /meals/photos).
//! - HU-07 la lee con [`read_own_photo`] (solo el dueño) para estimar sus valores (POST /meals/estimate).

use futures_util::io::{AsyncReadExt, AsyncWriteExt};
use mongodb::{
    Database,
    bson::{Bson, doc, from_document, oid::ObjectId, to_document},
    error::{ErrorKind, GridFsErrorKind},
    gridfs::{FilesCollectionDocument, GridFsBucket},
    options::GridFsBucketOptions,
};

use crate::error::{AppError, FieldErrors};
use crate::models::meal_photo::{MEAL_PHOTOS_BUCKET, MealPhotoMetadata, PhotoFormat};
use crate::services::coach_links;

/// Tamaño máximo de una foto: 5 MiB. HU-06 responde `413 PHOTO_TOO_LARGE` por encima de este valor.
pub const MAX_PHOTO_BYTES: usize = 5 * 1024 * 1024;

const JPEG_SIGNATURE: &[u8] = &[0xFF, 0xD8, 0xFF];
const PNG_SIGNATURE: &[u8] = &[0x89, b'P', b'N', b'G', 0x0D, 0x0A, 0x1A, 0x0A];

fn bucket(db: &Database) -> GridFsBucket {
    db.gridfs_bucket(
        GridFsBucketOptions::builder()
            .bucket_name(MEAL_PHOTOS_BUCKET.to_string())
            .build(),
    )
}

// ───────────────────────── Validación (funciones puras) ─────────────────────────

/// Foto que ya pasó la validación. Solo se construye con [`validate_photo`].
#[derive(Debug)]
pub struct ValidPhoto {
    bytes: Vec<u8>,
    format: PhotoFormat,
}

impl ValidPhoto {
    pub fn format(&self) -> PhotoFormat {
        self.format
    }

    pub fn size_bytes(&self) -> usize {
        self.bytes.len()
    }
}

/// Formato de la imagen según su firma (primeros bytes), o `None` si no es JPEG ni PNG.
pub fn detect_format(bytes: &[u8]) -> Option<PhotoFormat> {
    if bytes.starts_with(JPEG_SIGNATURE) {
        Some(PhotoFormat::Jpeg)
    } else if bytes.starts_with(PNG_SIGNATURE) {
        Some(PhotoFormat::Png)
    } else {
        None
    }
}

/// Comprueba tamaño y tipo. El tamaño se revisa primero para no analizar archivos enormes.
pub fn validate_photo(bytes: Vec<u8>) -> Result<ValidPhoto, AppError> {
    if bytes.len() > MAX_PHOTO_BYTES {
        return Err(AppError::PhotoTooLarge);
    }
    let format = detect_format(&bytes).ok_or(AppError::UnsupportedPhotoType)?;
    Ok(ValidPhoto { bytes, format })
}

/// HU-06 — valida el archivo recibido en la subida. Sin archivo, o con un archivo vacío, señala el campo `photo`;
/// después aplica las reglas de tamaño y tipo de [`validate_photo`].
pub fn validate_upload(bytes: Option<Vec<u8>>) -> Result<ValidPhoto, AppError> {
    match bytes {
        Some(bytes) if !bytes.is_empty() => validate_photo(bytes),
        _ => Err(AppError::Validation(FieldErrors::from([(
            "photo".to_string(),
            "Adjunta una foto de tu comida".to_string(),
        )]))),
    }
}

/// Regla de acceso de lectura: el dueño, o un coach con vinculación activa con el dueño.
fn may_read(requester_id: ObjectId, owner_id: ObjectId, has_active_link: bool) -> bool {
    requester_id == owner_id || has_active_link
}

// ───────────────────────── Persistencia ─────────────────────────

/// Foto leída del almacenamiento.
#[derive(Debug)]
pub struct StoredPhoto {
    pub id: ObjectId,
    pub owner_id: ObjectId,
    pub format: PhotoFormat,
    pub bytes: Vec<u8>,
}

/// Foto recién subida (HU-06).
#[derive(Debug)]
pub struct UploadedPhoto {
    pub id: ObjectId,
    pub format: PhotoFormat,
    pub size_bytes: usize,
}

/// HU-06 — valida el archivo recibido y lo guarda a nombre de `owner_id`.
pub async fn upload_photo(
    db: &Database,
    owner_id: ObjectId,
    bytes: Option<Vec<u8>>,
) -> Result<UploadedPhoto, AppError> {
    let photo = validate_upload(bytes)?;
    let (format, size_bytes) = (photo.format(), photo.size_bytes());
    let id = save_photo(db, owner_id, photo).await?;
    Ok(UploadedPhoto {
        id,
        format,
        size_bytes,
    })
}

/// Guarda la foto a nombre de `owner_id` y devuelve su id.
pub async fn save_photo(
    db: &Database,
    owner_id: ObjectId,
    photo: ValidPhoto,
) -> Result<ObjectId, AppError> {
    let id = ObjectId::new();
    let metadata = to_document(&MealPhotoMetadata {
        owner_id,
        format: photo.format,
    })
    .map_err(AppError::internal)?;

    let mut stream = bucket(db)
        .open_upload_stream(id.to_hex())
        .id(Bson::ObjectId(id))
        .metadata(metadata)
        .await
        .map_err(AppError::internal)?;
    if let Err(err) = stream.write_all(&photo.bytes).await {
        // `abort` borra los trozos que ya se escribieron.
        let _ = stream.abort().await;
        return Err(AppError::internal(err));
    }
    stream.close().await.map_err(AppError::internal)?;
    Ok(id)
}

/// Documento de la foto y su metadata, si existe.
async fn find_photo(
    db: &Database,
    photo_id: ObjectId,
) -> Result<Option<MealPhotoMetadata>, AppError> {
    let Some(file) = bucket(db)
        .find_one(doc! { "_id": photo_id })
        .await
        .map_err(AppError::internal)?
    else {
        return Ok(None);
    };
    file_metadata(file).map(Some)
}

fn file_metadata(file: FilesCollectionDocument) -> Result<MealPhotoMetadata, AppError> {
    let metadata = file
        .metadata
        .ok_or_else(|| AppError::internal("foto sin metadata en meal_photos.files"))?;
    from_document(metadata).map_err(AppError::internal)
}

/// Lee una foto si `requester_id` es su dueño o un coach con vinculación activa con el dueño.
/// Un id mal formado, inexistente o sin permiso responde igual: `PHOTO_NOT_FOUND`.
// TODO(HU-25): quitar el `allow` cuando la ruta que sirve la foto use `read_photo`.
#[allow(dead_code)]
pub async fn read_photo(
    db: &Database,
    requester_id: ObjectId,
    photo_id: &str,
) -> Result<StoredPhoto, AppError> {
    let photo_id = ObjectId::parse_str(photo_id).map_err(|_| AppError::PhotoNotFound)?;
    let metadata = find_photo(db, photo_id)
        .await?
        .ok_or(AppError::PhotoNotFound)?;

    let has_active_link = requester_id != metadata.owner_id
        && coach_links::has_active_link(db, requester_id, metadata.owner_id).await?;
    if !may_read(requester_id, metadata.owner_id, has_active_link) {
        return Err(AppError::PhotoNotFound);
    }
    download(db, photo_id, metadata).await
}

/// HU-07 — lee una foto **solo si es de `owner_id`**. Un id mal formado, inexistente o de otra cuenta (aunque sea de
/// un cliente vinculado) responde igual: `PHOTO_NOT_FOUND`.
pub async fn read_own_photo(
    db: &Database,
    owner_id: ObjectId,
    photo_id: &str,
) -> Result<StoredPhoto, AppError> {
    let photo_id = ObjectId::parse_str(photo_id).map_err(|_| AppError::PhotoNotFound)?;
    let metadata = find_photo(db, photo_id)
        .await?
        .filter(|metadata| metadata.owner_id == owner_id)
        .ok_or(AppError::PhotoNotFound)?;
    download(db, photo_id, metadata).await
}

/// Contenido de una foto cuyo permiso ya se revisó.
async fn download(
    db: &Database,
    photo_id: ObjectId,
    metadata: MealPhotoMetadata,
) -> Result<StoredPhoto, AppError> {
    let mut stream = bucket(db)
        .open_download_stream(Bson::ObjectId(photo_id))
        .await
        .map_err(map_gridfs_error)?;
    let mut bytes = Vec::new();
    stream
        .read_to_end(&mut bytes)
        .await
        .map_err(AppError::internal)?;

    Ok(StoredPhoto {
        id: photo_id,
        owner_id: metadata.owner_id,
        format: metadata.format,
        bytes,
    })
}

/// Elimina la foto del almacenamiento (documento y trozos). Solo su dueño puede hacerlo;
/// para cualquier otra cuenta responde `PHOTO_NOT_FOUND` y la foto no se toca.
// TODO(HU-09): quitar el `allow` cuando DELETE /meals/{id} use `delete_photo`.
#[allow(dead_code)]
pub async fn delete_photo(
    db: &Database,
    owner_id: ObjectId,
    photo_id: ObjectId,
) -> Result<(), AppError> {
    match find_photo(db, photo_id).await? {
        Some(metadata) if metadata.owner_id == owner_id => {}
        _ => return Err(AppError::PhotoNotFound),
    }
    bucket(db)
        .delete(Bson::ObjectId(photo_id))
        .await
        .map_err(map_gridfs_error)
}

/// Un archivo que desapareció entre la consulta y la operación (borrado concurrente) es `PHOTO_NOT_FOUND`.
fn map_gridfs_error(err: mongodb::error::Error) -> AppError {
    match *err.kind {
        ErrorKind::GridFs(GridFsErrorKind::FileNotFound { .. }) => AppError::PhotoNotFound,
        _ => AppError::internal(err),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn jpeg(len: usize) -> Vec<u8> {
        let mut bytes = JPEG_SIGNATURE.to_vec();
        bytes.resize(len, 0);
        bytes
    }

    fn png(len: usize) -> Vec<u8> {
        let mut bytes = PNG_SIGNATURE.to_vec();
        bytes.resize(len, 0);
        bytes
    }

    #[test]
    fn jpeg_se_detecta_por_su_firma() {
        assert_eq!(detect_format(&jpeg(100)), Some(PhotoFormat::Jpeg));
    }

    #[test]
    fn png_se_detecta_por_su_firma() {
        assert_eq!(detect_format(&png(100)), Some(PhotoFormat::Png));
    }

    #[test]
    fn otros_formatos_no_se_reconocen() {
        let gif = b"GIF89a\x01\x00\x01\x00".to_vec();
        let webp = b"RIFF\x00\x00\x00\x00WEBPVP8 ".to_vec();
        let pdf = b"%PDF-1.7\n".to_vec();
        for bytes in [gif, webp, pdf] {
            assert_eq!(detect_format(&bytes), None);
        }
    }

    #[test]
    fn texto_con_extension_de_imagen_se_rechaza_por_contenido() {
        // Lo que importa es el contenido: un "foto.jpg" que en realidad es texto no pasa.
        let result = validate_photo(b"esto no es una imagen".to_vec());
        assert!(matches!(result, Err(AppError::UnsupportedPhotoType)));
    }

    #[test]
    fn firma_incompleta_se_rechaza() {
        assert!(matches!(
            validate_photo(PNG_SIGNATURE[..4].to_vec()),
            Err(AppError::UnsupportedPhotoType)
        ));
        assert!(matches!(
            validate_photo(Vec::new()),
            Err(AppError::UnsupportedPhotoType)
        ));
    }

    #[test]
    fn foto_del_tamano_maximo_exacto_se_acepta() {
        let photo = validate_photo(jpeg(MAX_PHOTO_BYTES)).unwrap();
        assert_eq!(photo.format(), PhotoFormat::Jpeg);
    }

    #[test]
    fn foto_un_byte_mayor_al_maximo_es_demasiado_grande() {
        assert!(matches!(
            validate_photo(png(MAX_PHOTO_BYTES + 1)),
            Err(AppError::PhotoTooLarge)
        ));
    }

    #[test]
    fn archivo_grande_y_de_tipo_invalido_reporta_el_tamano() {
        assert!(matches!(
            validate_photo(vec![0; MAX_PHOTO_BYTES + 1]),
            Err(AppError::PhotoTooLarge)
        ));
    }

    #[test]
    fn subida_sin_archivo_senala_photo() {
        match validate_upload(None) {
            Err(AppError::Validation(fields)) => assert!(fields.contains_key("photo")),
            other => panic!("se esperaba VALIDATION_ERROR, llegó {other:?}"),
        }
    }

    #[test]
    fn subida_con_archivo_vacio_senala_photo() {
        match validate_upload(Some(Vec::new())) {
            Err(AppError::Validation(fields)) => assert!(fields.contains_key("photo")),
            other => panic!("se esperaba VALIDATION_ERROR, llegó {other:?}"),
        }
    }

    #[test]
    fn subida_valida_conserva_formato_y_tamano() {
        let photo = validate_upload(Some(png(1234))).unwrap();
        assert_eq!(photo.format(), PhotoFormat::Png);
        assert_eq!(photo.size_bytes(), 1234);
    }

    #[test]
    fn subida_aplica_las_reglas_de_tamano_y_tipo() {
        assert!(matches!(
            validate_upload(Some(jpeg(MAX_PHOTO_BYTES + 1))),
            Err(AppError::PhotoTooLarge)
        ));
        assert!(matches!(
            validate_upload(Some(b"GIF89a".to_vec())),
            Err(AppError::UnsupportedPhotoType)
        ));
    }

    #[test]
    fn el_dueno_puede_leer_su_foto() {
        let owner = ObjectId::new();
        assert!(may_read(owner, owner, false));
    }

    #[test]
    fn coach_con_vinculacion_activa_puede_leer() {
        assert!(may_read(ObjectId::new(), ObjectId::new(), true));
    }

    #[test]
    fn otra_cuenta_sin_vinculacion_no_puede_leer() {
        assert!(!may_read(ObjectId::new(), ObjectId::new(), false));
    }

    /// Pruebas contra MongoDB real. Se ejecutan con `cargo test -- --ignored` y una instancia sin autenticación
    /// (por defecto `mongodb://localhost:27017`; otra con la variable `TEST_MONGO_URI`). Cada prueba usa una base
    /// propia y la borra al terminar.
    mod mongo {
        use super::*;
        use crate::models::coach_link::{COACH_LINKS_COLLECTION, CoachLink, LinkStatus};
        use crate::models::meal_photo::{
            MEAL_PHOTOS_CHUNKS_COLLECTION, MEAL_PHOTOS_FILES_COLLECTION,
        };
        use mongodb::bson::{DateTime, Document};

        async fn test_db() -> Database {
            let uri = std::env::var("TEST_MONGO_URI")
                .unwrap_or_else(|_| "mongodb://localhost:27017".into());
            crate::db::connect(&uri, &format!("macrofit_test_{}", ObjectId::new())).await
        }

        async fn link(db: &Database, coach_id: ObjectId, user_id: ObjectId, status: LinkStatus) {
            db.collection::<CoachLink>(COACH_LINKS_COLLECTION)
                .insert_one(CoachLink {
                    id: ObjectId::new(),
                    coach_id,
                    user_id,
                    status,
                    created_at: DateTime::now(),
                })
                .await
                .unwrap();
        }

        async fn chunk_count(db: &Database, photo_id: ObjectId) -> u64 {
            db.collection::<Document>(MEAL_PHOTOS_CHUNKS_COLLECTION)
                .count_documents(doc! { "files_id": photo_id })
                .await
                .unwrap()
        }

        /// Foto de 600 KiB: ocupa varios trozos de GridFS (255 KiB cada uno).
        async fn saved_photo(db: &Database, owner: ObjectId) -> (ObjectId, Vec<u8>) {
            let bytes = png(600 * 1024);
            let id = save_photo(db, owner, validate_photo(bytes.clone()).unwrap())
                .await
                .unwrap();
            (id, bytes)
        }

        #[tokio::test]
        #[ignore = "requiere MongoDB"]
        async fn guardar_y_leer_devuelve_el_mismo_contenido_y_formato() {
            let db = test_db().await;
            let owner = ObjectId::new();
            let (id, bytes) = saved_photo(&db, owner).await;

            let photo = read_photo(&db, owner, &id.to_hex()).await.unwrap();
            assert_eq!(photo.bytes, bytes);
            assert_eq!(photo.format, PhotoFormat::Png);
            assert_eq!(photo.owner_id, owner);
            assert!(chunk_count(&db, id).await > 1);

            let file = db
                .collection::<Document>(MEAL_PHOTOS_FILES_COLLECTION)
                .find_one(doc! { "_id": id })
                .await
                .unwrap()
                .unwrap();
            assert_eq!(
                file.get_document("metadata")
                    .unwrap()
                    .get_object_id("owner_id")
                    .unwrap(),
                owner
            );
            db.drop().await.unwrap();
        }

        #[tokio::test]
        #[ignore = "requiere MongoDB"]
        async fn subir_guarda_la_foto_a_nombre_del_usuario() {
            let db = test_db().await;
            let owner = ObjectId::new();
            let bytes = jpeg(2048);

            let uploaded = upload_photo(&db, owner, Some(bytes.clone())).await.unwrap();
            assert_eq!(uploaded.format, PhotoFormat::Jpeg);
            assert_eq!(uploaded.size_bytes, 2048);

            let photo = read_photo(&db, owner, &uploaded.id.to_hex()).await.unwrap();
            assert_eq!(photo.owner_id, owner);
            assert_eq!(photo.bytes, bytes);
            db.drop().await.unwrap();
        }

        #[tokio::test]
        #[ignore = "requiere MongoDB"]
        async fn coach_con_vinculacion_activa_lee_la_foto_del_cliente() {
            let db = test_db().await;
            let (owner, coach) = (ObjectId::new(), ObjectId::new());
            link(&db, coach, owner, LinkStatus::Active).await;
            let (id, bytes) = saved_photo(&db, owner).await;

            let photo = read_photo(&db, coach, &id.to_hex()).await.unwrap();
            assert_eq!(photo.bytes, bytes);
            db.drop().await.unwrap();
        }

        #[tokio::test]
        #[ignore = "requiere MongoDB"]
        async fn cuentas_sin_permiso_reciben_foto_no_encontrada() {
            let db = test_db().await;
            let owner = ObjectId::new();
            let (unlinked_coach, other_coach, other_user) =
                (ObjectId::new(), ObjectId::new(), ObjectId::new());
            link(&db, unlinked_coach, owner, LinkStatus::Unlinked).await;
            // La vinculación de otro cliente no da acceso a las fotos de este.
            link(&db, other_coach, ObjectId::new(), LinkStatus::Active).await;
            let (id, _) = saved_photo(&db, owner).await;

            for requester in [unlinked_coach, other_coach, other_user] {
                let result = read_photo(&db, requester, &id.to_hex()).await;
                assert!(matches!(result, Err(AppError::PhotoNotFound)));
            }
            db.drop().await.unwrap();
        }

        #[tokio::test]
        #[ignore = "requiere MongoDB"]
        async fn solo_el_dueno_lee_su_foto_para_estimarla() {
            let db = test_db().await;
            let (owner, coach, other) = (ObjectId::new(), ObjectId::new(), ObjectId::new());
            // Ni un coach vinculado: la estimación (HU-07) es solo del dueño.
            link(&db, coach, owner, LinkStatus::Active).await;
            let (id, bytes) = saved_photo(&db, owner).await;

            let photo = read_own_photo(&db, owner, &id.to_hex()).await.unwrap();
            assert_eq!(photo.bytes, bytes);
            for requester in [coach, other] {
                let result = read_own_photo(&db, requester, &id.to_hex()).await;
                assert!(matches!(result, Err(AppError::PhotoNotFound)));
            }
            for missing in [ObjectId::new().to_hex(), "no-es-un-id".to_string()] {
                let result = read_own_photo(&db, owner, &missing).await;
                assert!(matches!(result, Err(AppError::PhotoNotFound)));
            }
            db.drop().await.unwrap();
        }

        #[tokio::test]
        #[ignore = "requiere MongoDB"]
        async fn id_inexistente_o_mal_formado_es_foto_no_encontrada() {
            let db = test_db().await;
            let owner = ObjectId::new();
            for id in [ObjectId::new().to_hex(), "no-es-un-id".to_string()] {
                let result = read_photo(&db, owner, &id).await;
                assert!(matches!(result, Err(AppError::PhotoNotFound)));
            }
            db.drop().await.unwrap();
        }

        #[tokio::test]
        #[ignore = "requiere MongoDB"]
        async fn solo_el_dueno_elimina_y_se_borran_todos_los_trozos() {
            let db = test_db().await;
            let (owner, coach) = (ObjectId::new(), ObjectId::new());
            link(&db, coach, owner, LinkStatus::Active).await;
            let (id, _) = saved_photo(&db, owner).await;

            // Ni el coach vinculado puede eliminar: la foto sigue intacta.
            let result = delete_photo(&db, coach, id).await;
            assert!(matches!(result, Err(AppError::PhotoNotFound)));
            assert!(read_photo(&db, owner, &id.to_hex()).await.is_ok());

            delete_photo(&db, owner, id).await.unwrap();
            assert_eq!(chunk_count(&db, id).await, 0);
            let result = read_photo(&db, owner, &id.to_hex()).await;
            assert!(matches!(result, Err(AppError::PhotoNotFound)));
            let result = delete_photo(&db, owner, id).await;
            assert!(matches!(result, Err(AppError::PhotoNotFound)));
            db.drop().await.unwrap();
        }

        #[tokio::test]
        #[ignore = "requiere MongoDB"]
        async fn el_arranque_crea_los_indices_del_bucket() {
            let db = test_db().await;
            let files = db
                .collection::<Document>(MEAL_PHOTOS_FILES_COLLECTION)
                .list_index_names()
                .await
                .unwrap();
            let chunks = db
                .collection::<Document>(MEAL_PHOTOS_CHUNKS_COLLECTION)
                .list_index_names()
                .await
                .unwrap();
            assert!(files.contains(&"filename_1_uploadDate_1".to_string()));
            assert!(files.contains(&"metadata_owner_id".to_string()));
            assert!(chunks.contains(&"files_id_1_n_1".to_string()));
            db.drop().await.unwrap();
        }
    }
}
