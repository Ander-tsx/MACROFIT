use mongodb::bson::{DateTime, oid::ObjectId};
use serde::{Deserialize, Serialize};

pub const EXERCISES_COLLECTION: &str = "exercises";

/// Grupo muscular principal del ejercicio.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum MuscleGroup {
    Chest,
    Back,
    Legs,
    Shoulders,
    Arms,
    Core,
}

impl MuscleGroup {
    pub fn all() -> &'static [MuscleGroup] {
        &[
            MuscleGroup::Chest,
            MuscleGroup::Back,
            MuscleGroup::Legs,
            MuscleGroup::Shoulders,
            MuscleGroup::Arms,
            MuscleGroup::Core,
        ]
    }

    pub fn as_str(&self) -> &'static str {
        match self {
            MuscleGroup::Chest => "chest",
            MuscleGroup::Back => "back",
            MuscleGroup::Legs => "legs",
            MuscleGroup::Shoulders => "shoulders",
            MuscleGroup::Arms => "arms",
            MuscleGroup::Core => "core",
        }
    }

    pub fn parse(value: &str) -> Option<Self> {
        match value.trim().to_lowercase().as_str() {
            "chest" => Some(MuscleGroup::Chest),
            "back" => Some(MuscleGroup::Back),
            "legs" => Some(MuscleGroup::Legs),
            "shoulders" => Some(MuscleGroup::Shoulders),
            "arms" => Some(MuscleGroup::Arms),
            "core" => Some(MuscleGroup::Core),
            _ => None,
        }
    }
}

/// Nivel de dificultad del ejercicio (mismos valores que el perfil).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ExerciseLevel {
    Beginner,
    Intermediate,
    Advanced,
}

impl ExerciseLevel {
    pub fn all() -> &'static [ExerciseLevel] {
        &[
            ExerciseLevel::Beginner,
            ExerciseLevel::Intermediate,
            ExerciseLevel::Advanced,
        ]
    }

    pub fn as_str(&self) -> &'static str {
        match self {
            ExerciseLevel::Beginner => "beginner",
            ExerciseLevel::Intermediate => "intermediate",
            ExerciseLevel::Advanced => "advanced",
        }
    }

    pub fn parse(value: &str) -> Option<Self> {
        match value.trim().to_lowercase().as_str() {
            "beginner" => Some(ExerciseLevel::Beginner),
            "intermediate" => Some(ExerciseLevel::Intermediate),
            "advanced" => Some(ExerciseLevel::Advanced),
            _ => None,
        }
    }
}

/// Documento de la colección `exercises`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Exercise {
    #[serde(rename = "_id")]
    pub id: ObjectId,
    pub name: String,
    pub muscle_group: MuscleGroup,
    pub equipment: String,
    pub level: ExerciseLevel,
    pub created_at: DateTime,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_muscle_group_acepta_todos_los_validos_y_rechaza_invalidos() {
        assert_eq!(MuscleGroup::parse("chest"), Some(MuscleGroup::Chest));
        assert_eq!(MuscleGroup::parse("CHEST "), Some(MuscleGroup::Chest));
        assert_eq!(MuscleGroup::parse("back"), Some(MuscleGroup::Back));
        assert_eq!(MuscleGroup::parse("legs"), Some(MuscleGroup::Legs));
        assert_eq!(
            MuscleGroup::parse("shoulders"),
            Some(MuscleGroup::Shoulders)
        );
        assert_eq!(MuscleGroup::parse("arms"), Some(MuscleGroup::Arms));
        assert_eq!(MuscleGroup::parse("core"), Some(MuscleGroup::Core));
        assert_eq!(MuscleGroup::parse("invalid"), None);
        assert_eq!(MuscleGroup::parse(""), None);
    }

    #[test]
    fn parse_exercise_level_acepta_todos_los_validos_y_rechaza_invalidos() {
        assert_eq!(
            ExerciseLevel::parse("beginner"),
            Some(ExerciseLevel::Beginner)
        );
        assert_eq!(
            ExerciseLevel::parse(" BEGINNER"),
            Some(ExerciseLevel::Beginner)
        );
        assert_eq!(
            ExerciseLevel::parse("intermediate"),
            Some(ExerciseLevel::Intermediate)
        );
        assert_eq!(
            ExerciseLevel::parse("advanced"),
            Some(ExerciseLevel::Advanced)
        );
        assert_eq!(ExerciseLevel::parse("expert"), None);
        assert_eq!(ExerciseLevel::parse(""), None);
    }
}
