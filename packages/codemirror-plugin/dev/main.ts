import { EditorView } from "@codemirror/view";
import { createEditorState } from "../dist/codemirror/create_editor_state.js";
import type { TypeDefinition } from "../dist/json/types.js";

const editorRoot = document.getElementById("editor");
if (!editorRoot) {
  throw new Error("Missing #editor element");
}

const schemaExample: TypeDefinition = {
        "type": {
          "kind": "record",
          "value": "service.skir:BatchAnalyzeRequest"
        },
        "records": [
          {
            "kind": "struct",
            "id": "service.skir:BatchAnalyzeRequest",
            "doc": "Request to analyze multiple shapes at once",
            "fields": [
              {
                "name": "shapes",
                "number": 0,
                "type": {
                  "kind": "array",
                  "value": {
                    "item": {
                      "kind": "record",
                      "value": "geometry.skir:DrawableShape"
                    }
                  }
                },
                "doc": "Shapes to analyze (demonstrates array field)"
              },
              {
                "name": "unit",
                "number": 1,
                "type": {
                  "kind": "record",
                  "value": "geometry.skir:MeasurementUnit"
                },
                "doc": "Measurement unit for all results"
              }
            ]
          },
          {
            "kind": "struct",
            "id": "geometry.skir:DrawableShape",
            "doc": "A drawable shape with metadata - demonstrates struct composition",
            "fields": [
              {
                "name": "id",
                "number": 0,
                "type": {
                  "kind": "primitive",
                  "value": "string"
                },
                "doc": "Unique identifier"
              },
              {
                "name": "label",
                "number": 1,
                "type": {
                  "kind": "primitive",
                  "value": "string"
                },
                "doc": "Human-readable label"
              },
              {
                "name": "geometry",
                "number": 2,
                "type": {
                  "kind": "record",
                  "value": "geometry.skir:Shape"
                },
                "doc": "The geometric shape"
              },
              {
                "name": "style",
                "number": 3,
                "type": {
                  "kind": "record",
                  "value": "geometry.skir:DrawingStyle"
                },
                "doc": "How to draw it"
              },
              {
                "name": "created_at",
                "number": 4,
                "type": {
                  "kind": "primitive",
                  "value": "timestamp"
                },
                "doc": "When it was created (demonstrates timestamp type)"
              },
              {
                "name": "modified_at",
                "number": 5,
                "type": {
                  "kind": "primitive",
                  "value": "timestamp"
                },
                "doc": "When it was last modified"
              }
            ]
          },
          {
            "kind": "enum",
            "id": "geometry.skir:Shape",
            "doc": "Geometric shape - demonstrates enum with wrapper variants",
            "variants": [
              {
                "name": "triangle",
                "number": 1,
                "doc": "A triangle defined by three vertices",
                "type": {
                  "kind": "record",
                  "value": "geometry.skir:Shape.Triangle"
                }
              },
              {
                "name": "circle",
                "number": 2,
                "doc": "A circle defined by center and radius",
                "type": {
                  "kind": "record",
                  "value": "geometry.skir:Shape.Circle"
                }
              },
              {
                "name": "rectangle",
                "number": 3,
                "doc": "A rectangle defined by top-left corner and dimensions",
                "type": {
                  "kind": "record",
                  "value": "geometry.skir:Shape.Rectangle"
                }
              },
              {
                "name": "polygon",
                "number": 4,
                "doc": "A general polygon defined by its vertices",
                "type": {
                  "kind": "record",
                  "value": "geometry.skir:Shape.Polygon"
                }
              }
            ]
          },
          {
            "kind": "struct",
            "id": "geometry.skir:Shape.Triangle",
            "fields": [
              {
                "name": "vertices",
                "number": 0,
                "type": {
                  "kind": "array",
                  "value": {
                    "item": {
                      "kind": "record",
                      "value": "geometry.skir:Point"
                    }
                  }
                },
                "doc": "The three corner points"
              }
            ]
          },
          {
            "kind": "struct",
            "id": "geometry.skir:Point",
            "doc": "A point in 2D space",
            "fields": [
              {
                "name": "x",
                "number": 0,
                "type": {
                  "kind": "primitive",
                  "value": "float64"
                }
              },
              {
                "name": "y",
                "number": 1,
                "type": {
                  "kind": "primitive",
                  "value": "float64"
                }
              }
            ]
          },
          {
            "kind": "struct",
            "id": "geometry.skir:Shape.Circle",
            "fields": [
              {
                "name": "center",
                "number": 0,
                "type": {
                  "kind": "record",
                  "value": "geometry.skir:Point"
                }
              },
              {
                "name": "radius",
                "number": 1,
                "type": {
                  "kind": "primitive",
                  "value": "float64"
                }
              }
            ]
          },
          {
            "kind": "struct",
            "id": "geometry.skir:Shape.Rectangle",
            "fields": [
              {
                "name": "top_left",
                "number": 0,
                "type": {
                  "kind": "record",
                  "value": "geometry.skir:Point"
                }
              },
              {
                "name": "width",
                "number": 1,
                "type": {
                  "kind": "primitive",
                  "value": "float64"
                }
              },
              {
                "name": "height",
                "number": 2,
                "type": {
                  "kind": "primitive",
                  "value": "float64"
                }
              }
            ]
          },
          {
            "kind": "struct",
            "id": "geometry.skir:Shape.Polygon",
            "fields": [
              {
                "name": "vertices",
                "number": 0,
                "type": {
                  "kind": "array",
                  "value": {
                    "item": {
                      "kind": "record",
                      "value": "geometry.skir:Point"
                    }
                  }
                },
                "doc": "Vertices in order (at least 3 required)"
              }
            ]
          },
          {
            "kind": "struct",
            "id": "geometry.skir:DrawingStyle",
            "doc": "Style properties for rendering a shape",
            "fields": [
              {
                "name": "fill_color",
                "number": 0,
                "type": {
                  "kind": "optional",
                  "value": {
                    "kind": "record",
                    "value": "geometry.skir:Color"
                  }
                },
                "doc": "Fill color (optional - null for no fill)"
              },
              {
                "name": "stroke_color",
                "number": 1,
                "type": {
                  "kind": "record",
                  "value": "geometry.skir:Color"
                },
                "doc": "Stroke color"
              },
              {
                "name": "stroke_width",
                "number": 2,
                "type": {
                  "kind": "primitive",
                  "value": "float64"
                },
                "doc": "Stroke width in pixels"
              }
            ]
          },
          {
            "kind": "struct",
            "id": "geometry.skir:Color",
            "doc": "RGB color with optional transparency",
            "fields": [
              {
                "name": "red",
                "number": 0,
                "type": {
                  "kind": "primitive",
                  "value": "int32"
                }
              },
              {
                "name": "green",
                "number": 1,
                "type": {
                  "kind": "primitive",
                  "value": "int32"
                }
              },
              {
                "name": "blue",
                "number": 2,
                "type": {
                  "kind": "primitive",
                  "value": "int32"
                }
              },
              {
                "name": "alpha",
                "number": 3,
                "type": {
                  "kind": "primitive",
                  "value": "int32"
                },
                "doc": "Alpha channel (0 = transparent, 255 = opaque)"
              }
            ]
          },
          {
            "kind": "enum",
            "id": "geometry.skir:MeasurementUnit",
            "doc": "Unit of measurement for distances and areas",
            "variants": [
              {
                "name": "METERS",
                "number": 1,
                "doc": "Metric system (meters, square meters)"
              },
              {
                "name": "FEET",
                "number": 2,
                "doc": "Imperial system (feet, square feet)"
              },
              {
                "name": "custom",
                "number": 3,
                "doc": "Custom unit with conversion factor to meters",
                "type": {
                  "kind": "primitive",
                  "value": "float64"
                }
              }
            ]
          }
        ]
      };

new EditorView({
  state: createEditorState({
  schema: schemaExample,
  theme: "quietlight",
}),
  parent: editorRoot,
});
