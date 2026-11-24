/// The symbols_check companion generator rebuilds every enum variant with the
/// provider's constructor from the value its value accessor reads, so a rebuilt
/// value equals the original only if both symbols agree with the generated
/// code.
#[cfg(test)]
mod tests {
    use crate::skirout::base::enums::{
        EnumWithNameConflict, EnumWithStructField, EnumWithStructField_S, JsonValue,
    };
    use crate::symbols_check::skirout::Rebuild;

    #[test]
    fn symbol_provider_rebuilds_constant_and_wrapper_variants() {
        let values = vec![
            JsonValue::Null,
            JsonValue::Boolean(true),
            JsonValue::String("skir".to_owned()),
            JsonValue::Array(vec![JsonValue::Number(1.0)]),
        ];
        for value in values {
            assert_eq!(value.rebuild(), value);
        }
    }

    #[test]
    fn symbol_provider_rebuilds_boxed_variants() {
        let value = EnumWithStructField::S(Box::new(EnumWithStructField_S {
            x: 1.0,
            y: 2.0,
            ..Default::default()
        }));
        assert_eq!(value.rebuild(), value);
    }

    #[test]
    fn symbol_provider_rebuilds_variants_with_conflicting_names() {
        let value = EnumWithNameConflict::If(true);
        assert_eq!(value.rebuild(), value);
    }
}
